#.ExternalHelp ../psWeblogic.Help.xml
function Set-WLDomain
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(

            [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
                [System.Management.Automation.PSObject]$InputObject,

            [Parameter(Mandatory=$True,  HelpMessage="Use managedServer name.")]
                [string]$AdminServer,

            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.")]
                [string]$Name,

            [Parameter(Mandatory=$False, HelpMessage="Use listen name.")]
            [ValidateRange(1,65535)]
                [int]$AdminTcpPort,

            [Parameter(Mandatory=$False, HelpMessage="Use Port Listener.")]
            [ValidateRange(1,65535)]
                [int]$AdminTcpPortSec,

            [Parameter(Mandatory=$False, HelpMessage="Use Environment definition.")]
                [string]$Environment,

            [Parameter(Mandatory=$False, HelpMessage="Use Windows service in which the AdminServer running this .")]
                [string]$ServiceName,

            [Parameter(Mandatory=$False, HelpMessage="Use domain version as string. Ex: 12.1.3")]
                [Version]$Version

        )

    BEGIN
    {
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
    }# BEGIN

    PROCESS
    {
        try
        {
            if ($PSBoundParameters.ContainsKey('InputObject'))
            {
                if ( $InputObject.PSObject.Properties['AdminServer'] -and ($InputObject.ResourceType -eq ('domain')) )
                {
                    $domainObject =  Get-WLDomain -AdminServer $InputObject.AdminServer
                }
                else 
                {
                    Write-Host The InputObject is invalid. -ForegroundColor Red
                    break
                }
            }
            elseif ($AdminServer)
            {
                $domainObject =  Get-WLDomain -AdminServer $AdminServer
            }
            else {break}

            #############################
            # Test required properties
            $defaultProperties = @('AdminServer','AdminTcpPort','AdminTcpPortSec','Description','Environment','MW_HOME','Name','ResourceType','ServiceName','Version')
            $defaultProperties | % {
                if (-not $domainObject.PSObject.Properties[$_])
                {
                    Write-Host "'$($_)' is a required property." -ForegroundColor Red
                    return
                }
            }

            #############################
            if ($Name)
            {
                $dmainObject.Name = $Name
            }
            if ($AdminTcpPort)
            {
                $dmainObject.AdminTcpPort = $AdminTcpPort
            }
            if($AdminTcpPortSec)
            {
                $domainObject.AdminTcpPortSec = $AdminTcpPortSec
            }
            if($Environment)
            {
                $domainObject.Environment = $Environment
            }
            if ($ServiceName)
            {
                $domainObject.ServiceName = $ServiceName
            }
            if ($Version)
            {
                $domainObject.Version = $Version
            }


            $domainsInfoPathPublish =$Script:config.parameters.Environment.DomainsInfoPathPublish

            # Retrieve environment (domains) info
            #$domainsInfoPath = $Script:config.parameters.environment.DomainsInfoPath
            if ($domainsInfoPathPublish -match "^(http|https)") # Case web resource
            {
                $domainsInfo = Invoke-RestMethod -Uri $domainsInfoPath -Method Get
            }
            elseif ($domainsInfoPathPublish -match "^([A-Z]:\\|\\\\)") # Case network (SMB) resource
            {
                if (Test-Path $domainsInfoPathPublish -PathType Leaf)
                {
                    $domainsInfo = (Get-Content -Path $domainsInfoPathPublish) -join "`n" | ConvertFrom-Json
                }
            }
            else
            {
                Write-Host "The path $($domainsInfoPathPublish) not is supported."
            }

                
                
            $domainsInfo = New-Object System.Collections.ArrayList
            $domainsInfo = Invoke-RestMethod -Uri $domainsInfoPath -Method Get
            $obj = $domainsInfo | ? {$_.AdminServer -eq $changeDomain.AdminServer}
                 
            if ($obj)
            {
                if (-not ($obj.Version -as [Version]))
                {
                    Write-Host "'$($obj.Version)' not is a valid version." -ForegroundColor Red
                    break
                }
                if (-not ($obj.AdminTcpPort -as [int32]))
                {
                    Write-Host "'$($obj.AdminTcpPort)' not is a valid port." -ForegroundColor Red
                    break
                }
                if (-not ($obj.AdminTcpPortSec -as [int32]))
                {
                    Write-Host "'$($obj.AdminTcpPortSec)' not is a valid port." -ForegroundColor Red
                    break
                }

                if (Compare-Object -ReferenceObject $obj -DifferenceObject $InputObject)
                {
                    $domainsInfo[$domainsInfo.IndexOf($obj)] = $InputObject

                    $domainsInfo | % {
                        $_.Version = $_.Version.ToString();
                    }

                    try
                    {
                        $domainsInfo | Sort-Object -Property AdminServer | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $domainsInfoPathPublish -Encoding ascii -Force -ErrorAction Stop
                        $output = $Script:domainsInfo | ? { ($_.AdminServer -match $AdminServer) }
                    }
                    catch [Exception]
                    {
                        Write-Log -message $_.Exception.Message -Level Error
                        Write-Host $_.Exception.Message -ForegroundColor Red
                    }
                }
            }
            else
            {
                Write-Host "The AdminServer $($obj.AdminServer) was not found." -ForegroundColor Red
                break
            }

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
