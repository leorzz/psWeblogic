#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLChangeManager
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding(DefaultParameterSetName='Parameter Set 1', 
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false
                  #HelpUri = 'http://www.microsoft.com/',
                  #ConfirmImpact='Medium'
                  )]
     #[OutputType([String])]

    param(
            [Parameter(Mandatory=$false, ParameterSetName='InputObject',ValueFromPipeline=$True)]
                [System.Management.Automation.PSObject]$InputObject,

            [Parameter(Mandatory=$false, HelpMessage="Use AdminServer name.")]
            [Parameter(ParameterSetName='AdminServer')]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$false, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$false, HelpMessage="Use to define SSL/TLS connections.")]
            #[Parameter(ParameterSetName='AdminServer')]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$false, HelpMessage="Use or not the cache for this query.")]
                [Switch]$Cache = $false,

                [int]$TimeoutSec = 30

    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
        #Ignore-SelfSignedCerts


    }# BEGIN

    PROCESS
    {
        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            foreach ($obj in $InputObject)
            {
                try
                {
                    $wl_domain = Get-WLDomain -AdminServer $obj.AdminServer | select -First 1
                    $operations = $Script:resources | ? { ($_.info.version -eq $wl_domain.Version) } | select -ExpandProperty operation

                    if ($obj.ResourceType -in ('domain'))
                    {
                        $basic = Invoke-WLResource -AdminServer $obj.AdminServer -Resource basic -Management -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                        $changeManager = Invoke-WLResource -AdminServer $obj.AdminServer -Resource changeManager -Management -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                        if ($basic -and $changeManager)
                        {
                            $uri = "$($changeManager.links | ? {$_.rel -eq 'parent'} | select -ExpandProperty uri)/changeManager"
                            $output = Join-Object -Left $basic.item -Right $changeManager.item -LeftJoinProperty * -RightJoinProperty *
                            $output | Add-Member -MemberType NoteProperty -Name AdminServer -Value $obj.AdminServer -ErrorAction SilentlyContinue | Out-Null
                            $output | Add-Member -MemberType NoteProperty -Name Credential -Value $Credential -ErrorAction SilentlyContinue | Out-Null
                            $output | Add-Member -MemberType NoteProperty -Name Uri -Value $uri -ErrorAction SilentlyContinue | Out-Null
                            $output | Add-Member -MemberType NoteProperty -Name ResourceType -Value ChangeManager -ErrorAction SilentlyContinue | Out-Null
                            

                            $operations = $Script:resources | ? { ($_.info.version -eq $obj.Version) } | select -ExpandProperty operation
                            if ($operations.domain.Lifecycle)
                            {
                                $operations.domain.Lifecycle | % {
                                    $oper = $_
                                    $code = @"
                                        Param(
                                            [Parameter(Position = 1)]
                                                [int]`$TimeoutSec=60,
                                            [Parameter(Position = 2, HelpMessage="Use <querystring=value>. e.g. '_detached=true'")]                                                
                                                [String[]]`$queryParameters=`$nul
                                        )
                                        try
                                        {
                                            if (`$queryParameters)
                                            {
                                                `$uri = "`$(`$this.Uri)/$($oper)?`$(`$queryParameters -join '&')"
                                            }
                                            else
                                            {
                                                `$uri = "`$(`$this.Uri)/$($oper)"
                                            }
                                            #write-host `$uri -fore red
                                            `$res = Update-WLResource -AdminServer `$this.AdminServer -Uri `$uri -Credential `$this.Credential -TimeoutSec `$TimeoutSec
                                            Write-Output `$res
                                        }
                                        catch [Exception]
                                        {
                                            Write-Log -message `$_ -Level EXCEPTION
                                            Write-Host `$_.Exception.Message
                                        }
"@
                                        $sb = $executioncontext.InvokeCommand.NewScriptBlock($code)
                                        Add-Member -InputObject $output -Name ((Get-Culture).TextInfo.ToTitleCase($oper)) -MemberType ScriptMethod -Value $sb
                                }
                            }


                            Set-StandardMembers -MyObject $output -DefaultProperties AdminServer,MergeNeeded,Locked,OverallServiceHealth
                            Write-Output $output
                        }
                    }
                }
                catch [Exception]
                {
                    Write-Log -message $_ -Level EXCEPTION
                    Write-Host $_.Exception.Message
                    break;
                }
            }
        }
        else #if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            if ($AdminServer)
            {
                try
                {
                    $basic = Invoke-WLResource -AdminServer $AdminServer -Resource basic -Management -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                    $changeManager = Invoke-WLResource -AdminServer $AdminServer -Resource changeManager -Management -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                    if ($basic -and $changeManager)
                    {
                        $uri = "$($changeManager.links | ? {$_.rel -eq 'parent'} | select -ExpandProperty uri)/changeManager"
                        $output = Join-Object -Left $basic.item -Right $changeManager.item -LeftJoinProperty * -RightJoinProperty *
                        $output | Add-Member -MemberType NoteProperty -Name AdminServer -Value $AdminServer -ErrorAction SilentlyContinue | Out-Null
                        $output | Add-Member -MemberType NoteProperty -Name Credential -Value $Credential -ErrorAction SilentlyContinue | Out-Null
                        $output | Add-Member -MemberType NoteProperty -Name Uri -Value $uri -ErrorAction SilentlyContinue | Out-Null
                        $output | Add-Member -MemberType NoteProperty -Name ResourceType -Value ChangeManager -ErrorAction SilentlyContinue | Out-Null

                        $operations = $Script:resources | ? { ($_.info.version -eq $(Get-WLDomain -AdminServer $AdminServer).Version) } | select -ExpandProperty operation
                        if ($operations.domain.Lifecycle)
                        {
                            $operations.domain.Lifecycle | % {
                                $oper = $_
                                $code = @"
                                    Param(
                                        [Parameter(Position = 1)]
                                            [int]`$TimeoutSec=60,
                                        [Parameter(Position = 2, HelpMessage="Use <querystring=value>. e.g. '_detached=true'")]                                                
                                            [String[]]`$queryParameters=`$nul
                                    )
                                    try
                                    {
                                        if (`$queryParameters)
                                        {
                                            `$uri = "`$(`$this.Uri)/$($oper)?`$(`$queryParameters -join '&')"
                                        }
                                        else
                                        {
                                            `$uri = "`$(`$this.Uri)/$($oper)"
                                        }
                                        #write-host `$uri -fore red
                                        `$res = Update-WLResource -AdminServer `$this.AdminServer -Uri `$uri -Credential `$this.Credential -TimeoutSec `$TimeoutSec
                                        Write-Output `$res
                                    }
                                    catch [Exception]
                                    {
                                        Write-Log -message `$_ -Level EXCEPTION
                                        Write-Host `$_.Exception.Message
                                    }
"@
                                    $sb = $executioncontext.InvokeCommand.NewScriptBlock($code)
                                    Add-Member -InputObject $output -Name ((Get-Culture).TextInfo.ToTitleCase($oper)) -MemberType ScriptMethod -Value $sb
                            }
                        }

                        Set-StandardMembers -MyObject $output -DefaultProperties AdminServer,MergeNeeded,Locked,OverallServiceHealth
                        Write-Output $output
                    }
                }
                catch [Exception]
                {
                    Write-Log -message $_ -Level EXCEPTION
                    Write-Host $_.Exception.Message
                    break;
                }

            }
        } #else AdminServer
    }# PROCESS

    END
    {

    }# END

}

Export-ModuleMember -Function Get-WLChangeManager