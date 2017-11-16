
function Update-WLResource
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory=$True, HelpMessage="Use a complete management uri.")]
                [string]$AdminServer,

            [Parameter(Mandatory=$False,HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True, HelpMessage="Use a relative resource path.")]
                [string]$Resource=$null,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True, HelpMessage="Use a complete management uri.")]
                [string]$Uri=$null,

            [Parameter(Mandatory=$False)]
                [switch]$Test,

            [Parameter(Mandatory=$False)]
                [String]$InFile = $null,

            [Parameter(Mandatory=$False)]
                [System.Collections.Hashtable]$Header,

            [Parameter(Mandatory=$False)]
                $Body = $null,

            [Parameter(Mandatory=$False)]
                [switch]$InvalidateCache,

            # https://msdn.microsoft.com/en-us/library/microsoft.powershell.commands.webrequestmethod(v=vs.85).aspx
            [Parameter(Mandatory=$False)]
            [ValidateSet('Post','Options','Delete')]
                [String]$Method = 'Post',
            [Parameter(Mandatory=$False)]
                [Switch]$SecureConnection,
            [Parameter(Mandatory=$False)]
                [int]$TimeoutSec = 30
    )


    #$session = $Script:session | ? { $_.AdminInfo.AdminServer -eq $AdminServer } | select -First 1
    #$wl_domain = Get-WLDomain -AdminServer $AdminServer | select -First 1    



    if (-not $Uri)
    {
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
            $resource_base = $Script:resources | ? { ($_.info.version | select Major,Minor,Build ) -match ($wl_domain.Version | select Major,Minor,Build) } | select -ExpandProperty management
        }
        catch [Exception]
        {
            Write-Log -message $_.Exception.Message -Level EXCEPTION
            Write-Host $_ -ForegroundColor Red
            return $False
        }
        $Uri = $protocol + $wl_domain.AdminServer + ":$($tcpPort)" + $resource_base.$($Resource)
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
        if (-not $Header)
        {
            $Header = @{"Accept" = "application/json"; 'Content-Type' = "application/json"; "X-Requested-By" = "MyClient"}
        }

        if ($InFile)
        {
            $header = @{"Accept" = "application/json"; "X-Requested-By" = "MyClient"}
            $fileBytes = [IO.File]::ReadAllBytes($InFile)
            $fileDataAsString = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)

            $boundary = [System.Guid]::NewGuid().ToString() 

            $bodyLines = @()
            $bodyLines += "--$boundary"
            $bodyLines += "Content-Disposition: form-data; name=`"model`""
            $bodyLines += ""
            $bodyLines += $($Body)

            $bodyLines += "--$boundary"
            $bodyLines += "Content-Disposition: form-data; name=`"deployment`"; filename=`"$(Split-Path $InFile -Leaf)`""
            $bodyLines += "Content-Type: application/octet-stream"
            $bodyLines += ""
            $bodyLines += $fileDataAsString
            $bodyLines += "--$boundary--"
            $bodyLines = $bodyLines -join "`r`n"


            $result = Invoke-RestMethod -Uri $Uri -Method $Method -Credential $Credential -TimeoutSec $TimeoutSec  `
                            -ContentType "multipart/form-data; boundary=$($boundary)" -Headers $header -Body $bodyLines -ErrorAction Stop
        }
        elseif ($Body)
        {
            $result = Invoke-RestMethod -Uri $Uri -Method $Method -Credential $Credential -TimeoutSec $TimeoutSec -Headers $header -Body $Body -ErrorAction Stop
        }
        else
        {
            $result = Invoke-RestMethod -Uri $Uri -Method $Method -Credential $Credential -TimeoutSec $TimeoutSec -Headers $header -ErrorAction Stop
        }

        if ($InvalidateCache.IsPresent)
        {
            #Remove-WLResourceCache -UriMatch $Uri
        }


    }
    catch
    {
        $j = $_.InvocationInfo | select @{E={$_.MyCommand.Name};L='MyCommand'},ScriptLineNumber,OffsetInLine,ScriptName
        $ex = $_ | select @{E={$_.Exception.Message};L='Exception'},@{E={$_.ErrorDetails};L='ErrorDetails'}
        Write-Log -message $_ -Level EXCEPTION
        Write-Debug "$($uri): $($_.Exception.Message)"
        $result = $ex
    }

    return $result
}
