#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLServer
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
            [Parameter(Mandatory=$False, ParameterSetName='InputObject',ValueFromPipeline=$True)]
                [System.Management.Automation.PSObject]$InputObject,

            [Parameter(Mandatory=$False, HelpMessage="Use AdminServer name.")]
            [Parameter(ParameterSetName='AdminServer')]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [System.Collections.Generic.List[String]]$Name,

            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
            #[Parameter(ParameterSetName='AdminServer')]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use to include AdminServer on results.")]
                [Switch]$IncludeAdminServer,

            [Parameter(Mandatory=$False, HelpMessage="Use or not the cache for this query.")]
                [Switch]$Cache = $Script:config.parameters.environment.CacheEnable,

            [Parameter(Mandatory = $False, HelpMessage="Use to access management features.")]
                [Switch]$Management,


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
            try
            {
                foreach ($obj in $InputObject)
                {
                    if ($obj.ResourceType -in ('domain','cluster','server'))
                    {
                        if (-not $PSBoundParameters.ContainsKey('AdminServer'))
                        {
                            if (-not $AdminServer)
                            {
                                $AdminServer = New-Object System.Collections.Generic.List[String]
                            }
                        
                            $null = $AdminServer.Add($obj.AdminServer)
                        }
                    }

                    if ($obj.ResourceType -in ('cluster'))
                    {
                        if (-not $clusters)
                        {
                            $clusters = New-Object System.Collections.ArrayList
                        }
                        $null = $clusters.Add($obj)
                    }

                    if ($obj.ResourceType -in ('server'))
                    {
                        if (-not $Name)
                        {
                            $Name = New-Object System.Collections.Generic.List[String]
                        }
                        $Name.Add($obj.Name)

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

    }# PROCESS

    END
    {
        $AdminServer = $AdminServer | select -Unique
        foreach ($admin in $AdminServer)
        {
            try
            {
                $server = Invoke-WLResource -AdminServer $admin -Resource servers -Management:$Management.IsPresent -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                if ($server)
                {
                    if ($Name)
                    {
                        $output = $server.items | ? {$_.Name -in $Name}
                    }
                    else
                    {
                        $output = $server.items
                    }

                    if ($clusters)
                    {
                        #$cluster = Invoke-WLResource -AdminServer $admin -Resource clusters -Management:$False -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                        $output = $output | ? { $_.Name -in $clusters.Servers.Name } 

                    }
                    $wl_domain = Get-WLDomain -AdminServer $admin | select -First 1
                    $operations = $Script:resources | ? { ($_.info.version -eq $wl_domain.Version) } | select -ExpandProperty operation
                    foreach ($out in $output)
                    { 
                        try
                        {
                            Add-Member -InputObject $out -MemberType NoteProperty -Name ResourceType -Value "Server" 
                            Add-Member -InputObject $out -MemberType NoteProperty -Name AdminServer -Value $admin

                            if ($clusters)
                            {
                                Add-Member -InputObject $out -MemberType NoteProperty -Name Cluster -Value (($clusters | ? {$_.Servers.Name -eq $out.Name}).Name)
                            }

                            if ($Management.IsPresent)
                            {
                                Add-Member -InputObject $out -MemberType NoteProperty -Name Credential -Value $Credential
                                Add-Member -InputObject $out -MemberType NoteProperty -Name Uri -Value ($server.links | ? {$_.Title -eq $out.Name}).Uri
                                #=========================================================================================
                                #=========================================================================================
                                if ($operations.server.Lifecycle)
                                {
                                    $operations.server.Lifecycle | % {
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
                                            Add-Member -InputObject $out -Name ((Get-Culture).TextInfo.ToTitleCase($oper)) -MemberType ScriptMethod -Value $sb
                                    }
                                }
                                #=========================================================================================
                                #=========================================================================================
                            }
                            Set-StandardMembers -MyObject $out -DefaultProperties Name,Health,State
                        }
                        catch [Exception]
                        {
                            Write-Log -message $_ -Level EXCEPTION
                            Write-Host $_.Exception.Message
                        }

                        if ($IncludeAdminServer.IsPresent)
                        {
                            Write-Output $out
                        }
                        else
                        {
                            $out = $out | ? { $_.Name -ne 'AdminServer' }
                            if ($out)
                            {
                                Write-Output $out
                            }
                        }
                        
                    }
                }#if ($server)
            }
            catch [Exception]
            {
                Write-Log -message $_.Exception.Message -Level Error
                Write-Host $_ -ForegroundColor Red
            }
        }

    }# END

}
Export-ModuleMember -Function Get-WLServer