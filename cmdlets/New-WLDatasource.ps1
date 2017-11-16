#.ExternalHelp ../psWeblogic.Help.xml
function New-WLDatasource
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding(DefaultParameterSetName='Default', 
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false
                  #HelpUri = 'http://www.microsoft.com/',
                  #ConfirmImpact='Medium'
                  )]
     #[OutputType([String])]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use AdminServer name.")]
                #[System.Collections.Generic.List[String]]$AdminServer=$null,
                [String]$AdminServer=$null,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True, ParameterSetName='InputObject')]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use to set datasource name.")]
                [string]$Name,

            [Parameter(Mandatory=$False, HelpMessage="Use to set datasource Url.")]
                [string]$Url,

            [Parameter(Mandatory=$False, HelpMessage="Use an PSobject containing the properties '[String]user' and '[SecureString]password'")]
                [System.Management.Automation.PSObject]$InputPasswordAsObject,


            [Parameter(Mandatory=$False, HelpMessage="Use an PSobject containing the properties '[String]user' and '[SecureString]password'")]
                [System.Management.Automation.PSObject]$InputUrlAsObject,

            [Parameter(Mandatory=$False, ParameterSetName='DatasourceType', HelpMessage="Use to set datasource name.")]
            [ValidateSet("Generic","Multi")]
                [string]$DatasourceType = "Generic",

            [Parameter(Mandatory=$False, HelpMessage="Use to set targets.")]
                [String[]]$Targets = $null,

            [Parameter(Mandatory=$False, HelpMessage="Use to set jndiNames.")]
                [String[]]$JndiNames = $null,

            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$DsCredential,


            [Parameter(Mandatory=$False, HelpMessage="Use minCapacity to the pool connection.")]
                [int]$MinCapacity = -1,

            [Parameter(Mandatory=$False, HelpMessage="Use maxCapacity to the pool connection.")]
                [int]$MaxCapacity = -1,

            [Parameter(Mandatory=$False, HelpMessage="Use initialCapacity to the pool connection.")]
                [int]$InitialCapacity = -1,
                
            [Parameter(Mandatory=$False, HelpMessage="Use database user to new datasource.")]
                [String]$DsUser,

            [Parameter(Mandatory=$False, HelpMessage="Use database password to new datasource.")]
                [SecureString]$DsPassword = $null,

            [Parameter(Mandatory=$False, HelpMessage="Use to not check if datasource or target exists at destination.")]
                [Switch]$SkeepChecks = $True,


                [int]$TimeoutSec = 30
    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
        $bagPipelineDatasources = New-Object -TypeName System.Collections.ArrayList
        $dataSourceMulti = New-Object -TypeName System.Collections.ArrayList
        $bagExtraDatasourcesNames = New-Object -TypeName System.Collections.ArrayList

    }# BEGIN

    PROCESS
    {
        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            $dsObjects = $InputObject
        }
        else
        {# Input parameters only
            if ($Name -and $Targets)
            {
                $dsObject = (Update-WLResource -AdminServer $AdminServer -Credential $Credential -Resource datasources -Method Options).item
                if ($dsObject)
                {
                    $dsObject | Add-Member -MemberType NoteProperty -Name AdminServer -Value $AdminServer
                    $dsObject | Add-Member -MemberType NoteProperty -Name ResourceType -Value 'Datasource'
                    $dsObject | Add-Member -MemberType NoteProperty -Name Type -Value $DatasourceType

                    if ($DatasourceType -eq 'Generic')
                    {
                        $dsObject.jdbcDriverParams.driverName = 'oracle.jdbc.OracleDriver'
                        While (-not $DsUser)
                        {
                            $DsUser = Read-Host -Prompt "Type a username to datasource"
                        }
                    }
                    elseif ($DatasourceType -eq 'Multi')
                    {
                        $dsObject.jdbcDriverParams.driverName = ''
                        do {
                            $dsObject.jdbcDataSourceParams.dataSourceList = Read-Host -Prompt "Type the dataSourceList to this Multi datasource (commna separator)"
                        }While(-not $dsObject.jdbcDataSourceParams.dataSourceList)
                    }
                    $dsObjects = $dsObject
                }
            }
            else
            {
                Write-Host "The parameter 'Name' and 'Targets' are required." -ForegroundColor Red
                break
            }
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
                $tmpDs = Get-WLDatasource -AdminServer $obj.AdminServer -Credential $Credential -Management -Name $obj.name -SecureConnection:$SecureConnection.IsPresent -TimeoutSec $TimeoutSec -Cache:$true
                if ($tmpDs)
                {
                    $obj = $tmpDs
                }
                else
                {
                    continue
                }
            }

            if ($Targets)
            {
                $obj.targets = $Targets
            }


            if ($PSBoundParameters.ContainsKey('InputObject'))
            {# pipeline only
                if ($obj.jdbcDataSourceParams.dataSourceList -eq $null) # if input ds is Generic
                {
                    $null = $bagPipelineDatasources.Add($obj)
                }
                else # if input ds is Multi
                {
                    $null = $dataSourceMulti.Add($obj)
                    
                    $obj.jdbcDataSourceParams.dataSourceList -split ',' | % { 
                        $extraDs = "" | Select Name,AdminServer
                        $extraDs.Name = $_
                        $extraDs.AdminServer = $obj.AdminServer
                        $null = $bagExtraDatasourcesNames.Add($extraDs) 
                    }
                }

                # Get extra datasources.
                if (-not $SkeepChecks.IsPresent)
                {
                    $bagExtraDatasourcesNames | % {
                        if ( ($bagPipelineDatasources.Count -eq 0) -or ($bagPipelineDatasources.Name -notcontains $_.Name) )
                        {
                            $exists_target = Get-WLDatasource -AdminServer $AdminServer -Credential $Credential -Name $_.Name -SecureConnection:$SecureConnection.IsPresent -TimeoutSec $TimeoutSec
                            if (-not $exists_target)
                            {
                                $ds = $null
                                $ds = Get-WLDatasource -AdminServer $_.AdminServer -Credential $Credential -Name $_.Name -Management -SecureConnection:$SecureConnection.IsPresent -TimeoutSec $TimeoutSec -Cache:$true
                                if ($ds)
                                {
                                    $null = $bagPipelineDatasources.Add($ds)
                                }
                            }
                        }
                    }
                }
                $dataSourceMulti | % { $null = $bagPipelineDatasources.Add($_) }

            }
            else
            {
                $null = $bagPipelineDatasources.Add($obj)
            }
        }


    }# PROCESS

    END
    { 
        $options = Update-WLResource -AdminServer $AdminServer -Credential $Credential -Resource datasources -Method Options
        $temp = $options | ConvertTo-Json -Depth 32
        if ( $options -isnot [Exception])
        {
            #do
            #{
                $bagPipelineDatasources = $bagPipelineDatasources | Sort-Object -Property Type,Name
                foreach ($datasource in $bagPipelineDatasources)
                { 
                    $msg = $null
                    $newDatasource = $temp | ConvertFrom-Json

                    #region COPY ATTRIBUTES FROM PIPELINE DATASOURCE
                            $properties = $datasource.jdbcDataSourceParams | gm -MemberType NoteProperty
                            $properties = $properties | ? { ($datasource.jdbcDataSourceParams.($_.Name) -ne $null) }
                            $properties | % {
                                                try
                                                {
                                                    $newDatasource.item.jdbcDataSourceParams.($_.Name) = $datasource.jdbcDataSourceParams.($_.Name)
                                                }
                                                catch [Exception]
                                                {
                                                    Write-Log -message $_.Exception -Level Error   
                                                }
                                            }

                            # jdbcConnectionPoolParams
                            $properties = $datasource.jdbcConnectionPoolParams | gm -MemberType NoteProperty
                            $properties = $properties | ? { ($datasource.jdbcConnectionPoolParams.($_.Name) -ne $null) }
                            $properties | % {
                                                try
                                                {
                                                    $newDatasource.item.jdbcConnectionPoolParams.($_.Name) = $datasource.jdbcConnectionPoolParams.($_.Name)
                                                }
                                                catch [Exception]
                                                {
                                                    Write-Log -message $_.Exception -Level Error   
                                                }

                                            }

                            # jdbcDriverParams 
                            $properties = $datasource.jdbcDriverParams | gm -MemberType NoteProperty
                            $properties = $properties | ? { ($datasource.jdbcDriverParams.($_.Name) -ne $null) }
                            $properties | % {
                                                try
                                                {
                                                    $newDatasource.item.jdbcDriverParams.($_.Name) = $datasource.jdbcDriverParams.($_.Name)
                                                }
                                                catch [Exception]
                                                {
                                                    Write-Log -message $_.Exception -Level Error   
                                                }

                                            }

                        #endregion COPY ATTRIBUTES FROM PIPELINE DATASOURCE


                    #region SET GENERAL ATTRIBUTES FROM PARAMETERS
                        if ($Name)
                        {
                            $newDatasource.item.Name = $Name
                        }
                        else
                        {
                            $newDatasource.item.Name = $datasource.name
                        }

                        if ( -not ($SkeepChecks.IsPresent) )
                        {
                            if (Get-WLDatasource -AdminServer $AdminServer -Name $newDatasource.item.Name -Cache:$true -SecureConnection:$SecureConnection.IsPresent)
                            {
                                $msg += "Datasource Name $($newDatasource.item.Name) is already exists at $AdminServer."
                            }
                        }

                        if ($Targets)
                        {
                            $newDatasource.item.targets = $Targets
                        }
                        else
                        {
                            $newDatasource.item.targets = $datasource.targets
                        }

                        if ( -not ($SkeepChecks.IsPresent) )
                        {
                            $targetsAvailable = Get-WLTarget -AdminServer $AdminServer -Name $newDatasource.item.targets -SecureConnection:$SecureConnection.IsPresent
                            $targetMissing = $newDatasource.item.targets | ? {$_ -notin $targetsAvailable.name}
                            if ($targetMissing)
                            {
                                $msg += "Target $($targetMissing | ConvertTo-Json) do not available in $AdminServer."
                            }
                        }

                        if ($MinCapacity -ge 0)
                        {
                            $newDatasource.item.jdbcConnectionPoolParams.minCapacity = $MinCapacity
                        }
                        if ($MaxCapacity -ge 0)
                        {
                            $newDatasource.item.jdbcConnectionPoolParams.maxCapacity = $MaxCapacity
                        }
                        if ($InitialCapacity -ge 0)
                        {
                            $newDatasource.item.jdbcConnectionPoolParams.initialCapacity = $InitialCapacity
                        }


                        if ($JndiNames)
                        {
                            $newDatasource.item.jdbcDataSourceParams.jndiNames = @($JndiNames)
                        }
                        elseif ($Name)
                        {
                            $newDatasource.item.jdbcDataSourceParams.jndiNames = @($Name)
                        }
                        else
                        {
                            $newDatasource.item.jdbcDataSourceParams.jndiNames = @($newDatasource.item.Name)
                        }

                    #endregion SET GENERAL ATTRIBUTES FROM PARAMETERS

                    if (-not $msg)
                    {
                        if ($datasource.jdbcDataSourceParams.dataSourceList -eq $null) # if input ds is generic
                        {
                            try
                            {
                            #region SET ATTRIBUTES FROM PARAMETERS
                                    if ($DsCredential)
                                    {
                                        $newDatasource.item.jdbcDriverParams.properties = @{'user'=$($DsCredential.UserName)}
                                        $DsPassword = $DsCredential.Password
                                    }
                                    else
                                    {
                                        if ($DsUser)
                                        {
                                            $newDatasource.item.jdbcDriverParams.properties = @(@{'value'=$DsUser;'name'='user'})
                                        }
                                        else
                                        {
                                            $DsUser = $newDatasource.item.jdbcDriverParams.properties | ? {$_.name -eq 'user'} | Select -ExpandProperty value
                                        }

                                        if ($DsUser)
                                        {
                                            if (-not $DsPassword)
                                            {
                                                if ($InputPasswordAsObject)
                                                {
                                                    $DsPassword = $InputPasswordAsObject | ? {$_.User -eq $DsUser} | select -First 1 | Select -ExpandProperty password
                                                }
                                            
                                                if (-not $DsPassword)
                                                {
                                                    do
                                                    {
                                                        $DsPassword = Read-Host -Prompt "Password to Datasource $($newDatasource.item.Name) / $($newDatasource.item.jdbcDriverParams.properties | ConvertTo-Json -Compress)" -AsSecureString
                                                    }While($DsPassword.Length -le 0)
                                                }
                                            }

                                            # Select the url connection
                                            if ($Url)
                                            {
                                                $newDatasource.item.jdbcDriverParams.url = $url
                                            }
                                            elseif ($InputUrlAsObject)
                                            {
                                                $url = $InputUrlAsObject | ? {$_.User -eq $DsUser} | select -First 1 | Select -ExpandProperty url
                                                if ($url)
                                                {
                                                    $newDatasource.item.jdbcDriverParams.url = $url
                                                }
                                            }
                                            else
                                            {
                                                if (-not $newDatasource.item.jdbcDriverParams.url)
                                                {
                                                    do
                                                    {
                                                        $url = Read-Host -Prompt "Url to Datasource $($newDatasource.item.Name)"
                                                        $newDatasource.item.jdbcDriverParams.url = $url
                                                    }While($Url.Length -le 0)
                                                }
                                            }


                                            $DsUser = $null
                                        }
                                        else
                                        {
                                            Write-Host The datasource name to $newDatasource not found.
                                            continue
                                        }
                                    }

                                    if (-not $plainPass)
                                    {
                                        $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DsPassword))
                                        $DsPassword = $null
                                    }
                                    #$DsPassword = $null
                                    if ([bool]($newDatasource.item.jdbcDriverParams.PSobject.Properties.name -contains "password"))
                                    {
                                        $newDatasource.item.jdbcDriverParams.password = $plainPass
                                    }
                                    else
                                    {
                                        $null = Add-Member -InputObject $newDatasource.item.jdbcDriverParams -MemberType NoteProperty -Name password -Value $plainPass
                                    }
                                    $plainPass = $null

                                #endregion SET ATTRIBUTES FROM PARAMETERS
                            
                            }
                            catch [Exception]
                            {
                                Write-Log -message $_.Exception -Level Error
                                Write-Host $_.Message -ForegroundColor Red
                            }

                        }
                        elseif($newDatasource.item.jdbcDataSourceParams.dataSourceList)
                        {
                            # The property driverName must be empty string. Can not be null
                            $newDatasource.item.jdbcDriverParams.driverName = ""

                            $dataSourceList = $bagPipelineDatasources | ? { $_.name -in ($newDatasource.item.jdbcDataSourceParams.dataSourceList -split ',') }
                            if ($newDatasource.item.targets -and $dataSourceList)
                            {
                                # Inteesect targets for all datasources
                                # This is necessary because the target should have been applied to all datasources members.
                                $intersect = $newDatasource.item.targets
                                for ( $i=0; $i -lt $dataSourceList.item.Count; $i++ )
                                {
                                    if ( ($i -lt $dataSourceList.Count -1) -and $intersect )
                                    {
                                        [Array]$intersect = Compare-Object -ReferenceObject $intersect -DifferenceObject $dataSourceList[$i+1].targets -IncludeEqual -ExcludeDifferent | select -ExpandProperty InputObject
                                    }
                                }

                                if ($intersect)
                                {
                                    $newDatasource.item.targets = @($intersect)
                                }
                                else
                                {
                                    $result = "There is no intersection of the chosen targets datasources."
                                    Add-Member -InputObject $newDatasource.item -MemberType NoteProperty Messages -Value $result
                                    Set-StandardMembers -MyObject $newDatasource.item -DefaultProperties Name,Targets,Messages
                                    Write-Output $newDatasource.item
                                    return
                                }
                            }
                        }

                    }# if (-not $msg)
                    else
                    {
                        Write-Host $msg
                        continue
                    }

                    #region CREATE DATASOURCE
                        try
                        {
                            $result = Update-WLResource -AdminServer $AdminServer -Credential $Credential -Resource datasources -Body ($newDatasource.item | ConvertTo-Json -Depth 100) -Method Post -SecureConnection:$SecureConnection.IsPresent
                            if ($result)
                            {
                                # Remove the list of datasource
                                #$null = $bagPipelineDatasources.Remove($datasource)
                                Remove-WLResourceCache -UriMatch "$($AdminServer).*datasources"
                                if ([bool]($result.PSobject.Properties.name -contains "messages"))
                                {
                                    $msg += $result.messages
                                    #Add-Member -InputObject $newDatasource.item -MemberType NoteProperty -Name Messages -Value $result.messages
                                }
                                elseif ([bool]($result.PSobject.Properties.name -contains "message"))
                                {
                                    $msg += $result.message
                                    
                                }
                                else
                                {
                                    $msg += $result
                                }

                                Add-Member -InputObject $newDatasource.item -MemberType NoteProperty -Name Messages -Value $msg
                                $msg = $null
                                Add-Member -InputObject $newDatasource.item -MemberType NoteProperty -Name AdminServer -Value $AdminServer
                                Add-Member -InputObject $newDatasource.item -MemberType NoteProperty -Name ResourceType -Value "datasource" 

                                Set-StandardMembers -MyObject $newDatasource.item -DefaultProperties Name,Targets,Messages
                                Write-Log -message ($newDatasource.item.Messages | ConvertTo-Json -Compress) -Level SECURITY
                                Write-Output $newDatasource.item
                                
                            }
                            else
                            {
                                $result = New-Item -Path $env:TEMP -Name 'invalid_data.json' -Force -ItemType file -Value ($objTemp | ConvertTo-Json -Depth 100)
                                Write-Host "The server refused the data sent. View logs for details." -ForegroundColor Red
                                Write-Host "Aditionally, a result file was created in $($result.FullName)"
                            }
                        }
                        catch [Exception]
                        {
                            Write-Log -message $_.Exception -Level Error
                            Write-Host $_.Message -ForegroundColor Red
                        }
                    #endregion CREATE DATASOURCE


                }# foreach ($datasource in $bagPipelineDatasources)
            
                # If dataSourceMulti, return while loop one time
            #    $endwhile = $false
            #    if ($dataSourceMulti.Count -gt 0)
            #    {
            #        $bagPipelineDatasources = $dataSourceMulti.Clone()
            #        $dataSourceMulti.Clear()
            #        $endwhile = $true
            #    }
            #}While ($endwhile)
        }# if ( $options )
    }# END
}
Export-ModuleMember -Function New-WLDatasource