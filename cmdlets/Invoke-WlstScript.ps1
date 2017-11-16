#.ExternalHelp ../psWeblogic.Help.xml
function Invoke-WlstScript
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
            [System.Management.Automation.PSObject]$InputObject,

        [Parameter(Mandatory=$false, HelpMessage="Use PSCredential object.")]
            [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

        [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections. Need configrure AdminServer secure port em WLST.")]
            [Switch]$SecureConnection,


        #[Parameter(Mandatory=$False, ParameterSetName="InputPasswordAsObject", HelpMessage="Use an PSobject containing the properties '[String]AdminServer', [String]username and '[SecureString]password'")]
        #[System.Management.Automation.PSObject]$InputPasswordAsObject,

        [Parameter(Mandatory=$false, ParameterSetName='ScriptPath')]
            [string]$ScriptPath,

        [Parameter(Mandatory=$false, HelpMessage="Looks for a prefix at the beginning of the output lines and converts it from csv to object format.")]
            [string]$PrefixToObject='==>',

        [Parameter(Mandatory=$false, HelpMessage="Looks for a prefix at the beginning of the output lines and converts it from csv to object format.")]
            [Char]$DelimiterToObject=',',

        [Parameter(Mandatory=$false)]
            [Switch]$PassThru=$True,

        [Parameter(Mandatory=$false)]
            [Switch]$CurrentBaseDir,

        [Parameter(Mandatory=$false)]
            [Switch]$WhatIf,


        [Parameter(Mandatory=$false)]
            [string[]]$Arguments

    )

    DynamicParam {
                # Set the dynamic parameters' name
                $ParameterName = 'BuiltInScript'
                # Create the collection of attributes
                $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                # Create and set the parameters' attributes
                $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
                $ParameterAttribute.Mandatory = $false
                $ParameterAttribute.ParameterSetName = "BuildinScript"
                #$ParameterAttributeTemplate.Position = 1
                # Add the attributes to the attributes collection
                $AttributeCollection.Add($ParameterAttribute)
                # Generate and set the ValidateSet 
                $arrSet = Get-ChildItem -Path (Join-Path -Path (Join-Path -Path ($Script:mInfo.ModuleBase) -ChildPath script) -ChildPath python) -File | Select-Object -ExpandProperty Name
                $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
                # Add the ValidateSet to the attributes collection
                $AttributeCollection.Add($ValidateSetAttribute)
                # Create the dynamic parameter
                $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)

                # Create the dictionary 
                $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)

                # Return the dynamic parameter
                return $RuntimeParameterDictionary
        }

    BEGIN
    {
        Import-Module psKeePass

        try
        {
            if ($PsBoundParameters[$ParameterName])
            {
                $scriptbase = (Join-Path -Path $Script:mInfo.ModuleBase -ChildPath script\python)
                $ScriptPath = Join-Path $scriptbase $PsBoundParameters[$ParameterName]
            }

            if ( -not (Test-Path $ScriptPath -PathType Leaf) )
            {
                Write-Host "Script not found at $($ScriptPath)." -ForegroundColor Red
                break
            }

            $pyFile = Get-Item -LiteralPath $ScriptPath
            $pyContent = $pyFile  | Get-Content


            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                if (-not $Credential)
                {
                    $Credential = Get-Credential -Message "Type username and password."
                    if (-not $Credential)
                    {
                        Write-Host Adminserver credentials is empty or null. Aborted. -ForegroundColor Red
                        break;
                    }
                }
            }
            $currentLocation = Get-Location
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            Write-Host $_.Exception.Message
            return
        }
   


#        $wlstCmd = @"
#@ECHO OFF
#CALL $($Script:config.parameters.environment.WLST) %* 2> nul
#"@
#        $wlstFile = New-Item -Path (Join-Path $PSScriptRoot bin\wlst.cmd) -ItemType File -Value $wlstCmd -Force

        
    }
    PROCESS
    {
        if($InputObject)
        {
            foreach ($obj in $InputObject)
            {
                if ($obj.ResourceType -eq 'domain')
                {

                    if (Test-Path ([System.IO.Path]::Combine($obj.MW_HOME, 'wlserver_12.1\common\bin\wlst.cmd')))
                    {
                        $wlst = [System.IO.Path]::Combine($obj.MW_HOME, 'wlserver_12.1\common\bin\wlst.cmd')
                    }
                    elseif (Test-Path ([System.IO.Path]::Combine($obj.MW_HOME, 'oracle_common\common\bin\wlst.cmd')))
                    {
                        $wlst = [System.IO.Path]::Combine($obj.MW_HOME, 'oracle_common\common\bin\wlst.cmd')
                    }
                    elseif (Test-Path $Script:config.parameters.environment.WLST)
                    {
                        $wlst = $Script:config.parameters.environment.WLST
                    }
                    else
                    {
                        Write-Host "The $($obj.MW_HOME) is not found." -ForegroundColor Red
                        Write-Host "If wlst.cmd is not located from the MW_HOME property originating from Get-WLDomain the`n'parameters.environment.WLST'property is used in the <module_root>\environment\parameters.json file." -ForegroundColor Green
                        continue;
                    }

                    $scriptContent = Get-Content -LiteralPath $ScriptPath

                    
                    foreach ($line in $scriptContent)
                    {
                        if ($scriptContent.indexOf($line) -eq 0)
                        {
                            if ($WhatIf.IsPresent)
                            {
                                $scriptContent[$scriptContent.indexOf($line)] = "whatif = True`r`n" + $line
                            }
                            else
                            {
                                $scriptContent[$scriptContent.indexOf($line)] = "`nwhatif = False`r`n" + $line
                            }
                        }
                        if ($line -match "^#@domain_hashtable")
                        {
                            $obj_tmp = $obj | select *
                            $obj_tmp.Version = $obj.Version.ToString()
                            $domain_hashtable = $obj_tmp | ConvertTo-Json -Depth 2 -Compress
                            #$domain_hashtable = $obj | select Name,AdminServer,AdminTcpPort,@{E={($_.Version).toString()};L='Version'},Environment,MW_HOME  | ConvertTo-Json -Depth 1 -Compress
                            $scriptContent[$scriptContent.indexOf($line)] = "domain_hashtable=$($domain_hashtable)"
                        }

                        if ($line -match "(^|\s)connect\(\)")
                        {
                            if (-not $Credential)
                            {
                                $Credential = Get-Credential -Message "Type username and password."
                                if (-not $Credential)
                                {
                                    Write-Host Adminserver credentials are required to run this script. Aborted. -ForegroundColor Red
                                    break;
                                }
                            }

                            $user = $Credential.UserName
                            $pass = ConvertTo-PlainText -secure $Credential.Password

                            if ($user -and $pass)
                            {
                                if ($SecureConnection.IsPresent)
                                {
                                    $connect = "connect('$($user)','$($pass)','t3s://$($obj.AdminServer):$($obj.AdminTcpPort)')"
                                }
                                else
                                {
                                    $connect = "connect('$($user)','$($pass)','t3://$($obj.AdminServer):$($obj.AdminTcpPort)')"
                                }

                                $indexOf = $line.IndexOf('c')
                                $connect = $connect.PadLeft(($connect.Length + $indexOf), ' ')

                                #$scriptContent[$scriptContent.indexOf($line)] = $line -replace "(^|\s)connect\(\)",$connect
                                $scriptContent[$scriptContent.indexOf($line)] = $connect
                                $connEnable = $true
                            }
                            else
                            {
                                Write-Host "Credentials to $($obj.AdminServer) not found." -ForegroundColor Red
                            }
                            $user, $pass = $null
                        }
                    }# foreach ($line in $scriptContent)

                    if ($CurrentBaseDir.IsPresent)
                    {
                        $tmpScript = Join-Path (Split-Path $ScriptPath -Parent) "$(Get-Random)_$(Split-Path $ScriptPath -Leaf)"
                        New-Item $tmpScript -ItemType File -Force -ErrorAction Stop| %{$_.Attributes = "hidden"}
                    }
                    else
                    {
                        $tmpScript = [System.IO.Path]::GetTempFileName()
                    }

                    Set-Content -LiteralPath $tmpScript -Value $scriptContent -Force
                    #$targetServer = "$($obj.AdminServer):$($obj.AdminTcpPort)"
                    #Invoke-Command -ComputerName $obj.AdminServer -ScriptBlock $cmd -InputObject $pyFile,$pyContent,$obj,$ScriptParameters
                    
                    #Set-Location (Split-Path $tmpScript -Parent)
                    Push-Location (Split-Path $tmpScript -Parent)
                    try
                    {
                        $python_tmp = Split-Path $tmpScript -Leaf
                        $cmd = "$($wlst) $($python_tmp) $($Arguments -join ' ')"


                        if ($PassThru.IsPresent)
                        {
                            Invoke-Expression -Command $cmd
                        }
                        else
                        {
                            $result  = Invoke-Expression -Command $cmd -ErrorAction SilentlyContinue
                            $obj | Add-Member -MemberType NoteProperty -Name Result -Value $($result | Out-String) -Force
                            Set-StandardMembers -MyObject $obj -DefaultProperties AdminServer,Result
                            if ($PrefixToObject)
                            {
                                try
                                {
                                    #"(?<=($($PrefixToObject))).*"

                                    $matchLines = $obj.Result -split "`r`n" | ? {$_ -match "^$($PrefixToObject)"}
                                    if ($matchLines.Count -gt 0)
                                    {
                                        $oMatchLines = $matchLines | % {$_ -replace "^$($PrefixToObject)",""} | select -Unique | ConvertFrom-Csv -Delimiter $DelimiterToObject -ErrorAction Stop
                                        if ($oMatchLines)
                                        {
                                            $obj.Result = $oMatchLines
                                            Write-Output $obj
                                        }
                                        else
                                        {
                                            Write-Host "$($obj.AdminServer):No object can be converted. Use <prefix><csv format delimited with commas>" -ForegroundColor Red
                                        }
                                    }
                                    else
                                    {
                                        Write-Host "$($obj.AdminServer):No prefix '$($PrefixToObject)' match found in lines. Use <prefix><csv format delimited with commas>" -ForegroundColor Red
                                        Write-Output $obj
                                    }

                                }
                                catch [Exception]
                                {
                                    Write-Log -message $_.Exception -Level EXCEPTION
                                    Write-Host $_.Exception.Message
                                }
                            }
                            else
                            {
                                Write-Output $obj
                            }
                        }

                        # & $wlstCmd (Split-Path $tmpScript -Leaf) ($Arguments -join ' ')
                    }
                    catch [Exception]
                    {
                        Write-Log -message $_.Exception -Level EXCEPTION
                        Write-Host $_.Exception.Message
                    }
                    Remove-Item -LiteralPath $tmpScript -Force
                    
                }# if ($obj.ResourceType -eq 'domain'
            }#foreach ($obj in $InputObject)
        }
        else
        {
            Write-Host `nUse input domain info from pipeline. -ForegroundColor Red
            Write-Host "eg. 'Get-WLDomain -AdminServer fqdn_adminserver | Invoke-WlstScript -BuiltInScript New-Domain.py -Arguments wl_password'" -ForegroundColor Green
        }
    }
    END
    {
        Pop-Location
        #$currentLocation | Set-Location
    }
}
Export-ModuleMember -Function Invoke-WlstScript