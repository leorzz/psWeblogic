#.ExternalHelp ../psWeblogic.Help.xml
function New-WLDomain
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(

            [Parameter(Mandatory=$True,  HelpMessage="Use managedServer name.")]
                [string]$AdminServer,

            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.")]
                [string]$Name,

            [Parameter(Mandatory=$True, HelpMessage="Use listen name.")]
            [ValidateRange(1,65535)]
                [int]$AdminTcpPort,

            [Parameter(Mandatory=$False, HelpMessage="Use Port Listener.")]
            [ValidateRange(1,65535)]
                [int]$AdminTcpPortSec = 443,

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.",ParameterSetName='AdminServer')]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use Secure Port Listener.")]
                [string]$Environment,

            [Parameter(Mandatory=$False, HelpMessage="Use Windows service in which the AdminServer running this .")]
                [string]$ServiceName,

            [Parameter(Mandatory=$False, HelpMessage="Use domain version as string. Eg. 12.1.3")]
                [Version]$Version,

            [Parameter(Mandatory=$False, HelpMessage="Use Windows service in which the AdminServer running this .")]
                [string]$MW_HOME,

            [Parameter(Mandatory=$False)]
                [String]$Description,

            
            [int]$TimeoutSec = 30

        )


    BEGIN
    {
        # Teste Write permissions
        function Test-Write {
            [CmdletBinding()]
            param (
                [parameter()] 
                #[ValidateScript({[IO.Directory]::Exists($_.FullName)})]
                #[IO.DirectoryInfo] $Path
                    [String] $Path
            )
            try 
            {
                if ($Path -match "^FileSystem::")
                {
                    $Path = $Path -replace "FileSystem::",""
                }
                $testPath = Join-Path $Path ([IO.Path]::GetRandomFileName())
                [IO.File]::Create($testPath, 1, 'DeleteOnClose') > $null
                # Or...
                <# New-Item -Path $testPath -ItemType File -ErrorAction Stop > $null #>
                return $true
            } catch {
                return $false
            } finally {
                Remove-Item $testPath -ErrorAction SilentlyContinue -WhatIf:$false
            }
        }
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition


    }# BEGIN

    PROCESS
    {
        try
        {
            $domainsInfoPathPublish =$Script:config.parameters.Environment.DomainsInfoPathPublish
            $domainsInfoPath =$Script:config.parameters.Environment.DomainsInfoPath

            $domainsInfo = Get-WLDomain | Select-Object * -ExcludeProperty ResourceType

            # Retrieve environment (domains) info
            try
            {
                $obj = "" | select AdminServer,Name,Environment,Version,AdminTcpPort,AdminTcpPortSec,ServiceName,MW_HOME,Description
                $obj.AdminServer = $AdminServer
                $obj.Name = $Name
                $obj.Environment = $Environment
                $obj.AdminTcpPort = $AdminTcpPort
                $obj.AdminTcpPortSec = $AdminTcpPortSec
                $obj.ServiceName = $ServiceName
                $obj.MW_HOME = $MW_HOME
                $obj.Description = $Description

                $isWritable = Test-Write -Path (Split-Path -Path $domainsInfoPathPublish -Parent)
                if ($domainsInfo)
                {

                    if ( ($isWritable) -and ($domainsInfoPathPublish -match "^([a-zA-Z]:\\|\\\\|FileSystem::\\|/)") ) # Case writable and filesystem resource
                    {
                        $domainExists = $domainsInfo | ? { ($_.AdminServer -match $AdminServer) -and (($_.AdminTcpPort -match $AdminTcpPort) -or ($_.AdminTcpPortSec -match $AdminTcpPortSec)) }
                        if ($domainExists)
                        {
                            Write-Host "The AdminServer $($AdminServer) Ports $($AdminTcpPort) or $($AdminTcpPortSec) already exists and the entry could not be created." -ForegroundColor Red
                            return $null
                        }
                    }
                    else
                    {
                        Write-Host "The path $($domainsInfoPathPublish) is invalid or read only. " -NoNewline
                        Write-Host "To this, use a filesystem path or 'null' to DomainsInfoPath parameter at parameters.json." -ForegroundColor Cyan
                        $domainsInfoPathPublish = Join-Path -Path $Script:appdata -ChildPath inventory.json
                    }

                }

                if (-not $Version)
                {

                    try
                    {
                        if ($SecureConnection.IsPresent -and $AdminTcpPortSec)
                        {
                            $domain = Invoke-RestMethod -Uri "https://$($AdminServer):$($AdminTcpPortSec)/management/wls" -Credential $Credential -TimeoutSec $TimeoutSec
                        }
                        else
                        {
                            $domain = Invoke-RestMethod -Uri "http://$($AdminServer):$($AdminTcpPort)/management/wls" -Credential $Credential -TimeoutSec $TimeoutSec
                        }
                    }
                    catch{}

                    if ($domain)
                    {
                        $Version = Split-Path ($domain.links | ? {$_.rel -eq 'current'}).uri -Leaf
                    }
                    else
                    {
                        Write-Host "Not be able contact the resource /management/wls on AdminsServer $($AdminServer). Try to type the version." -ForegroundColor Cyan
                        do
                        {
                            [Version]$Version = Read-Host -Prompt "Type the AdminServer version (eg. 12.1.3.0)" -ErrorAction SilentlyContinue
                        }While(-not $Version)
                    }
                }
                $obj.Version = $Version
                $Script:domainsInfo = New-Object System.Collections.ArrayList
                $null = $domainsInfo | % { $Script:domainsInfo.Add($_) }
                $null = $Script:domainsInfo.Add($obj)
                
                $Script:domainsInfo | % {
                    $_.Version = $_.Version.ToString();
                }
                $Script:domainsInfo | Sort-Object -Property AdminServer | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $domainsInfoPathPublish -Encoding ascii -Force
                $output = $Script:domainsInfo | ? { ($_.AdminServer -match $AdminServer) }
            }
            catch [Exception]
            {
                Write-Log -message $_ -Level EXCEPTION
                Write-Host $_.Exception.Message -ForegroundColor Red
                return $false
            }
            
            Write-Host "Inventory file created in '$($domainsInfoPathPublish)'." -ForegroundColor Cyan
            Write-Output $output
        }
        catch [Exception]
        {
            Write-Log -message $_.Exception.Message -Level Error
            Write-Host $_ -ForegroundColor Red
        }
    }# PROCESS

    END
    {

    }# END

}
Export-ModuleMember -Function New-WLDomain