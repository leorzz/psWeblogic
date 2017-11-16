
function Invoke-WLResource
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory=$True, HelpMessage="Use a complete management uri.")]
                [string]$AdminServer,

            [Parameter(Mandatory=$True,ValueFromPipeline=$True, HelpMessage="Use a complete management uri.")]
                [string]$Resource,

            [Parameter(Mandatory=$False,HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential,

            [Parameter(Mandatory=$False)]
                [switch]$Test,

            [Parameter(Mandatory=$False)]
                [Switch]$SecureConnection,

            [Parameter(Mandatory=$False)]
                [Switch]$Cache,

            [Parameter(Mandatory = $False, HelpMessage="Use to access management features.")]
                [Switch]$Management,

            [Parameter(Mandatory=$False)]
                [int]$TimeoutSec = 30
    )


    $session = $Script:session | ? { ($_.AdminInfo.AdminServer -eq $AdminServer) -and ($_.Method -eq "Get") } | select -Unique
    $wl_domain = Get-WLDomain -AdminServer $AdminServer | select -First 1
    
    

    if ($SecureConnection.IsPresent)
    {
        $protocol = "https://"
        $tcpPort = $wl_domain.AdminTcpPortSec
    }
    else
    {
        $protocol = "http://"
        $tcpPort = $wl_domain.AdminTcpPort
    }

    try
    {
        $resource_base = $Script:resources | ? { ($_.info.version | select Major,Minor,Build ) -match ($wl_domain.Version | select Major,Minor,Build) }
        if ($Management.IsPresent)
        {
            $resource_base = $resource_base | select -ExpandProperty 'management'
        }
        else
        {
            $resource_base = $resource_base | select -ExpandProperty 'monitoring'
        }
    }
    catch [Exception]
    {
        Write-Log -message $_.Exception.Message -Level EXCEPTION
        Write-Host $_ -ForegroundColor Red
        return $False
    }

    try
    {
        #if ($resource_base.$($Resource))
        #if ($resource_base.PsObject.Properties.Name -contains $Resource)
        if ( $resource_base -and ((Get-Member -InputObject $resource_base -ErrorAction Stop | ? {$_.MemberType -eq 'NoteProperty'} | select -ExpandProperty name) -contains $Resource) )
        {
            $Uri = $protocol + $wl_domain.AdminServer + ":$($tcpPort)" + $resource_base.$($Resource)
        }
        elseif ($Resource -match "^/")
        {
            $Uri = $protocol + $AdminServer + ":$($tcpPort)" + $Resource   
        }
        else
        {
            #$Uri = $protocol + $AdminServer + ":$($tcpPort)" + $Resource
            Write-Host "Resource '$($Resource)' is not available on $($wl_domain.AdminServer) version:$($wl_domain.Version.ToString())." -ForegroundColor Cyan
            return $false
        }
    }
    catch [Exception]
    {
        Write-Log -message $_.Exception.Message -Level EXCEPTION
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $False
    }


    if ($Test.IsPresent)
    {
        $result = Test-Url -url $uri -Credentials $Credential -Timeout $TimeoutSec
        if ($result.StatusCodeInt -eq 200)
        {
            return $True
        }
        else
        {
            return $False
        } 
    }

    
    try
    {
        [bool]$cacheEnable = $Script:config.parameters.environment.CacheEnable
    }
    catch [Exception]
    {
        $cacheEnable = $False
    }




    if ($session)
    {
        try
        {
            $wl_domain = $session.AdminInfo

            $result = Get-WLResourceCache -Uri $Uri -UserName $session.WebSession.Credentials.UserName
            if (-not $result -or (-not $Cache.IsPresent))
            {

                if (-not $Credential)
                {
                    $Credential = Get-Credential -Message "Type the credentials to the weblogic Adminserver: $($wl_domain.AdminServer)"
                    if (-not $Credential)
                    {
                        Write-Host "Credentials to the weblogic Adminserver $($wl_domain.AdminServer) not available."
                    }
                }

                #Write-Debug "Uri '$($Uri)' new query."
                $result = Invoke-RestMethod -Uri $Uri -Method Get -WebSession $session.WebSession -TimeoutSec $TimeoutSec -Headers @{"Accept"="application/json"} 
                New-WLResourceCache -Uri $Uri -UserName $session.WebSession.Credentials.UserName -ResourceObject $result
            }
            else
            {
#                Write-Debug "Uri '$($Uri)' getting in cache."
            }
        }
        catch
        {
            try
            {
                if (-not $result -or (-not $Cache.IsPresent))
                {
                    $result = Invoke-RestMethod -Uri $Uri -Method Get -SessionVariable ws -TimeoutSec $TimeoutSec -Credential $Credential -Headers @{"Accept"="application/json"} 
                    $session.WebSession = $ws
                    New-WLResourceCache -Uri $Uri -UserName $session.WebSession.Credentials.UserName -ResourceObject $result
                }

            }
            catch [Exception]
            {
                Write-Log -message $_ -Level EXCEPTION
                Write-Host "$($wl_domain.AdminServer): $($_.Exception.Message)" -ForegroundColor Red
                return $False
            }
        }
    }
    else
    {

        $session = "" | select WebSession,Method,AdminInfo

        try
        {
            if (-not $Credential)
            {
                if (-not ($Credential = Get-Credential -Message "Type credentials to adminserver $($wl_domain.AdminServer)"))
                {
                    return
                }
            }
            $session.AdminInfo = $wl_domain
            #Write-Host $Uri -ForegroundColor Green
            $result = Get-WLResourceCache -Uri $Uri -UserName $session.WebSession.Credentials.UserName
            if (-not $result -or (-not $Cache.IsPresent))
            {
                $result = Invoke-RestMethod -Uri $Uri -Method Get -SessionVariable ws -TimeoutSec $TimeoutSec -Credential $Credential -Headers @{"Accept"="application/json"} 
                $session.Method = "Get"
                $session.WebSession = $ws
                New-WLResourceCache -Uri $Uri -UserName $session.WebSession.Credentials.UserName -ResourceObject $result
                #Write-Debug "Uri '$($Uri)' new query."
            }
            $null = $Script:session.Add($session)
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            Write-Host "$($wl_domain.AdminServer): $($_.Exception.Message)" -ForegroundColor Red
            return $False
        } 

        #$changeManager = Invoke-RestMethod -Uri "https://$($wl_domain.AdminServer):$($wls_domain.AdminTcpPort)/management/wls/latest/changeManager" -Method Get -SessionVariable websession -TimeoutSec $TimeoutSec -Credential $Credential
        #$changeManager.item.locked
    }

    if ($result)
    {
        if ($Management.IsPresent)
        {
            #$result.items | % { Add-Member -InputObject $_ -MemberType NoteProperty -Name Tenant -Value $Tenant }
            return $result
        }
        else
        {
            #$result.Body.items | % { Add-Member -InputObject $_ -MemberType NoteProperty -Name Tenant -Value $Tenant }
            return $result.Body
        }
    }
    else
    {
        return $False
    }
}
