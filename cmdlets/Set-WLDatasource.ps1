#.ExternalHelp ../psWeblogic.Help.xml
function Set-WLDatasource
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.",ParameterSetName='AdminServer')]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [string]$Name,

            [Parameter(Mandatory=$False)]
                [string[]]$JndiNames,

            [Parameter(Mandatory=$False)]
                [string[]]$Targets,

            [Parameter(Mandatory=$False)]
                [string]$Url,

            [Parameter(Mandatory=$False)]
                [string]$DriverName,

            [Parameter(Mandatory=$False)]
                [ValidateRange(0,2147483647)]
                [Int32]$InitialCapacity,

            [Parameter(Mandatory=$False)]
                [ValidateRange(0,2147483647)]
                [Int32]$MinCapacity,

            [Parameter(Mandatory=$False)]
                [ValidateRange(0,2147483647)]
                [Int32]$MaxCapacity,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow,ParameterSetName='InputObject')]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

                [int]$TimeoutSec = 30
    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
    }# BEGIN

    PROCESS
    {
        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            $dsObjects = $InputObject
        }

        foreach ($obj in $dsObjects)
        {
            if ($obj.ResourceType -notcontains 'Datasource')
            {
                Write-Host InputObject $($obj.Name) is not invalid. Use a datasource type. -ForegroundColor Red
                continue
            }

            if (-not $AdminServer)
            {
                if ($obj.PsObject.Properties.Name -contains 'AdminServer')
                {
                    $AdminServer = $obj.AdminServer
                }
                else
                {
                    Write-host "Invalid input object $($obj.Name)." -ForegroundColor Red
                    continue
                }
            }

            if ( $obj.PsObject.Properties.Name -notcontains 'jdbcDriverParams' )
            {
                $tmpDs = $null
                $secure = $true
                if ($obj.Uri -notmatch "^https://")
                {
                    $secure = $false
                }
                $tmpDs = Get-WLDatasource -AdminServer $obj.AdminServer -Credential $Credential -Management -Name $obj.name -SecureConnection:$secure -TimeoutSec $TimeoutSec -Cache:$true
                if ($tmpDs)
                {
                    $obj = $tmpDs
                }
                else
                {
                    continue
                }
            }

            #region Set Properties by parameters
                if ($MaxCapacity)
                {
                    $obj.jdbcConnectionPoolParams.maxCapacity = $MaxCapacity

                }

                if ($MinCapacity)
                {
                    if ($MinCapacity -le $obj.jdbcConnectionPoolParams.maxCapacity)
                    {
                        $obj.jdbcConnectionPoolParams.minCapacity = $MinCapacity
                    }
                    else
                    {
                        Write-Host MinCapacity shoud be less than maxCapacity:$($obj.jdbcConnectionPoolParams.maxCapacity) -ForegroundColor Red
                    }
                }

                if ($InitialCapacity)
                {
                    if ($InitialCapacity -le $obj.jdbcConnectionPoolParams.maxCapacity)
                    {
                        $obj.jdbcConnectionPoolParams.initialCapacity = $InitialCapacity
                    }
                    else
                    {
                        Write-Host MinCapacity shoud be less than maxCapacity:$($obj.jdbcConnectionPoolParams.maxCapacity) -ForegroundColor Red
                    }
                }


                if ($Name)
                {
                    $obj.name = $Name
                }

                if ($JndiNames)
                {
                    $obj.jdbcDataSourceParams.jndiNames = $JndiNames
                }

                if ($DriverName)
                {
                    $obj.jdbcDriverParams.driverName = $DriverName
                }

                if ($Url)
                {
                    $obj.jdbcDriverParams.url = $Url
                }

                #if ($Targets)
                #{
                    $obj.targets = $Targets
                #}

                #$obj.jdbcDriverParams.properties
                $obj.jdbcDriverParams | Add-Member -MemberType NoteProperty -Name password -Value "cpu"

            #region Set Properties by parameters

            #$properties = $obj.jdbcConnectionPoolParams | gm -MemberType NoteProperty
            $properties = $properties | ? { ($obj.jdbcConnectionPoolParams.($_.Name) -eq $null) }
            $properties | ForEach-Object { $obj.jdbcConnectionPoolParams.($_.Name) = '' }

            $json = $obj | select name,targets,jdbcDriverParams,jdbcDataSourceParams,jdbcConnectionPoolParams | ConvertTo-Json -Depth 32
            try
            {
                $result = Update-WLResource -AdminServer $obj.AdminServer -Uri $obj.Uri -Method Post -Credential $Credential -TimeoutSec $TimeoutSec -Body $json
                Remove-WLResourceCache -UriMatch "$($obj.AdminServer).*datasources"
                #Invoke-RestMethod -Method Post -Uri $ds.Uri -Credential $cred -Body $json -Headers $header | fl
            }
            catch [Exception]
            {
                Write-Log -message $_ -Level Error   
                $err = $_.Exception
            }

            Add-Member -InputObject $obj -Name Messages -MemberType NoteProperty -Value $null -Force
            #Add-Member -InputObject $obj -Name Item -MemberType NoteProperty -Value $null -Force

            if ($result -is [Exception])
            {
                $m = "" | select message,severity
                $m.message = "Restart the server '$($obj.name)'."
                $m.message += "$($result.Message)"
                $m.severity = 'ERROR'
                $messages = @($m)
                $Obj.Messages = $messages
            }
            else
            {
                $msg = $result.messages | select *
                $Obj.Messages = $msg
                #$obj.Item = $result.item
            }
            Set-StandardMembers -MyObject $obj -DefaultProperties Name,Messages
            Write-Output $obj

        }

    }# PROCESS

    END
    { 


    }# END

}