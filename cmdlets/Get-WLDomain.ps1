#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLDomain
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]
     [OutputType([System.Collections.ArrayList])]

    param(

            [Parameter(Mandatory=$False,  HelpMessage="Use managedServer name.")]
                [string[]]$AdminServer,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [string[]]$Name,

            [Parameter(Mandatory=$False, HelpMessage="Use or not the cache for this query.")]
                [Switch]$Cache,

            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.")]
                [string[]]$Environment,

            [Parameter(Mandatory=$False, HelpMessage="Use domain version as string. Ex: 12.1.3")]
                [Version[]]$Version,

                [int]$TimeoutSec = 30    
        )


    BEGIN
    {
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
    }# BEGIN

    PROCESS
    {
        try
        {
            $domainsInfoPath = $Script:config.parameters.environment.DomainsInfoPath
            if ($domainsInfoPath)
            {
                if ($Cache.IsPresent)
                {
                    if (Get-WLResourceCache -Uri $domainsInfoPath -OutVariable values)
                    {
                        if ($values)
                        {
                            $Script:domainsInfo = $values.Value
                        }
                    }
                    else
                    {
                        Repair-WLCacheIndex -Force
                        $Script:domainsInfo = (Get-WLResourceCache -Uri $domainsInfoPath).value
                    }

                }

                if ( (-not $Script:domainsInfo) -or (-not $Cache.IsPresent) )
                {
                    try
                    {
                        $Script:domainsInfo = New-Object System.Collections.ArrayList

                        # Retrieve environment (domains) info
                        if ($domainsInfoPath -match "^(http|https)") # Case web resource
                        {
                            #$Script:domainsInfo = Invoke-RestMethod -Uri $domainsInfoPath -UseBasicParsing -Method Get
                            $Script:domainsInfo = Invoke-RestMethod -Uri $domainsInfoPath -Method Get -Headers @{"Cache-Control"="no-cache"} -ErrorAction SilentlyContinue
                        }
                        elseif ($domainsInfoPath -match "^([a-zA-Z]:\\|\\\\|FileSystem::\\|/)") # Case filesystem
                        {
                            if (Test-Path $domainsInfoPath -PathType Leaf)
                            {
                                $Script:domainsInfo = (Get-Content -Path $domainsInfoPath -ErrorAction SilentlyContinue) -join "`n" | ConvertFrom-Json
                            }
                        }

                        #New-WLResourceCache -Uri $domainsInfoPath -ResourceObject $Script:domainsInfo
                        if ($Script:domainsInfo)
                        {
                            $Script:domainsInfo | % {
                                Add-Member -InputObject $_ -MemberType NoteProperty -Name ResourceType -Value "Domain"
                                if ($_.PSObject.Properties.Match('ServiceName').Value)
                                                                                                                                                                                                                                                                                                {
                                $start = { 
                                    try
                                    {
                                        $serverAdmin = Resolve-DnsName -Name $This.AdminServer -ErrorAction SilentlyContinue | ? QueryType -eq A
                                        if ($serverAdmin.Name)
                                        {
                                            $computername = $serverAdmin.Name
                                        }
                                        else
                                        {
                                            $computername = $This.AdminServer
                                        }
                                        Get-Service -ComputerName $computername -Name $This.ServiceName -ErrorAction SilentlyContinue | Start-Service -PassThru 
                                    }
                                    catch [Exception]
                                    {
                                        Write-Log -message $_ -Level EXCEPTION
                                        Write-Host $_.Exception.Message -ForegroundColor Red
                                    }
                                }
                                Add-Member -InputObject $_ -MemberType ScriptMethod -Name Start -Value $start

                                $stop = { 
                                    try
                                    {
                                        $serverAdmin = Resolve-DnsName -Name $This.AdminServer -ErrorAction SilentlyContinue | ? QueryType -eq A
                                        if ($serverAdmin.Name)
                                        {
                                            $computername = $serverAdmin.Name
                                        }
                                        else
                                        {
                                            $computername = $This.AdminServer
                                        }
                                        Get-Service -ComputerName $computername -Name $This.ServiceName -ErrorAction SilentlyContinue | Stop-Service -PassThru -Force
                                    }
                                    catch [Exception]
                                    {
                                        Write-Log -message $_ -Level EXCEPTION
                                        Write-Host $_.Exception.Message -ForegroundColor Red
                                    }
                                }
                                Add-Member -InputObject $_ -MemberType ScriptMethod -Name Stop -Value $stop

                                $restart = { 
                                    try
                                    {
                                        $serverAdmin = Resolve-DnsName -Name $This.AdminServer -ErrorAction SilentlyContinue | ? QueryType -eq A
                                        if ($serverAdmin.Name)
                                        {
                                            $computername = $serverAdmin.Name
                                        }
                                        else
                                        {
                                            $computername = $This.AdminServer
                                        }
                                        Get-Service -ComputerName $computername -Name $This.ServiceName -ErrorAction SilentlyContinue | Restart-Service -PassThru -Force
                                    }
                                    catch [Exception]
                                    {
                                        Write-Log -message $_ -Level EXCEPTION
                                        Write-Host $_.Exception.Message -ForegroundColor Red
                                    }
                                }
                                Add-Member -InputObject $_ -MemberType ScriptMethod -Name Restart -Value $restart

                            }

                                try
                                {
                                    [Version]$_.Version = $_.Version
                                }
                                catch [Exception]
                                {
                                    Write-Log -message $_ -Level EXCEPTION
                                    Write-Host $_.Exception.Message -ForegroundColor Red
                                }
                            }
                            New-WLResourceCache -Uri $domainsInfoPath -ResourceObject $Script:domainsInfo
                        }
                    }
                    catch
                    {
                        $Script:domainsInfo = Get-WLResourceCache -Uri $domainsInfoPath -Force
                    }
                }
            }#if ($domainsInfoPath)
            else
            {
                $Script:domainsInfo = Get-WLResourceCache -Uri $domainsInfoPath -Force
            }


       
            if ($Script:domainsInfo)
            {
                $output = $Script:domainsInfo
                if ($AdminServer)
                {
                    $output = $output | ? {$_.AdminServer -in $AdminServer}
                }

                if ($Name)
                {
                    $output = $output | ? {$_.Name -in $Name}
                }

                if ($Environment)
                {
                    $output = $output | ? {$_.Environment -in $Environment}
                }
                
                if ($Version)
                {
                    $output = $output | ? {$_.Version -in $Version}
                }
                $output = $output | Sort-Object -Property Name,AdminServer
                Write-Output $output
            }
            else
            {
                Write-Host Fail to get inventory. -ForegroundColor Red
            }
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $false
        }
    }# PROCESS

    END
    {

    }# END

}
Export-ModuleMember -Function Get-WLDomain