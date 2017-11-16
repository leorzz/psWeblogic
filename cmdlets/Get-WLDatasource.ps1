#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLDatasource
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.",ParameterSetName='AdminServer')]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [string[]]$Name,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow,ParameterSetName='InputObject')]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

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
    }# BEGIN

    PROCESS
    {
        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            if ($InputObject.PsObject.Properties.Name -contains 'AdminServer')
            {
                $AdminServer = $InputObject.AdminServer | select -Unique
                if ($InputObject.ResourceType -in ('Target','Cluster','Server'))
                {
                    $local:targets = $InputObject
                }
            }
            else
            {
                Write-Host AdminServer property not available on InputObject -ForegroundColor Cyan 
            }
        }

        foreach ($admin in $AdminServer)
        {
            try
            {
                $datasource = Invoke-WLResource -AdminServer $admin -Resource datasources -Credential $Credential -Management:$Management.IsPresent -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                if ($datasource.items)
                {
                    $output = $datasource.items
                    if ($name)
                    {
                        #$datasource.items = $datasource.items | ? { $_.name -match $name }
                        $output = $output | ? { $Name -contains $_.name }
                    }

                    if ($local:targets)
                    {
                        if ($Management.IsPresent)
                        {
                            $output = $output | ? { $_.targets | ? {$_ -in $local:targets.Name} }
                        }
                        else
                        {
                            if ($local:targets.ResourceType -in ('Server'))
                            {
                                $output = $output | ? { $_.instances.server | ? {$_ -in $local:targets.name} }
                            }
                            elseif ($local:targets.ResourceType -in ('Cluster'))
                            {
                                $output = $output | ? { $_.servers.name | ? {$_ -in $targets.name} }
                            }
                            elseif ($local:targets.ResourceType -in ('Target'))
                            {
                                $ds = Invoke-WLResource -AdminServer $admin -Resource datasources -Credential $Credential -Management -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                                $ds = $ds.items | ? { $_.targets | ? {$_ -in $targets.name} }
                                $output = $output | ? {$_.name -in $ds.name}
                            }
                        }
                    }


                    $wl_domain = Get-WLDomain -AdminServer $admin | select -First 1
                    $operations = $Script:resources | ? { ($_.info.version -eq $wl_domain.Version) } | select -ExpandProperty operation

                    foreach ($out in $output)
                    { 
                        Add-Member -InputObject $out -MemberType NoteProperty -Name AdminServer -Value $admin
                        Add-Member -InputObject $out -MemberType NoteProperty -Name ResourceType -Value "Datasource" 
                    

                        if ($Management.IsPresent)
                        {
                            Add-Member -InputObject $out -MemberType NoteProperty -Name Credential -Value $Credential
                            Add-Member -InputObject $out -MemberType NoteProperty -Name User -Value ($out.jdbcDriverParams.properties | ? {$_.Name -eq 'user'} | select -ExpandProperty value)
                            Add-Member -InputObject $out -MemberType NoteProperty -Name Uri -Value ($datasource.links | ? {$_.Title -eq $out.Name}).Uri

                            if ($out.jdbcDataSourceParams.dataSourceList)
                            {
                                Add-Member -InputObject $out -MemberType NoteProperty -Name Type -Value 'Multi'
                            }
                            else
                            {
                                Add-Member -InputObject $out -MemberType NoteProperty -Name Type -Value 'Generic'
                            }

                            Set-StandardMembers -MyObject $out -DefaultProperties Name,Targets

                            #=========================================================================================
                            #=========================================================================================
                            if ($operations.datasource.Lifecycle)
                            {
                                $operations.datasource.Lifecycle | % {
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
                                                `$res = Update-WLResource -AdminServer `$this.AdminServer -Uri "`$(`$this.Uri)/$($oper)?`$(`$queryParameters -join '&')" -Credential `$this.Credential -TimeoutSec `$TimeoutSec
                                            }
                                            else
                                            {
                                                `$res = Update-WLResource -AdminServer `$this.AdminServer -Uri "`$(`$this.Uri)/$($oper)" -Credential `$this.Credential -TimeoutSec `$TimeoutSec
                                            }
                                            #Set-StandardMembers -MyObject `$res -DefaultProperties Item
                                            if (`$res -is [System.InvalidOperationException])
                                            {
                                                `$m = "" | select message,severity
                                                `$m.message = "Data Source '`$(`$this.Name)'. `$(`$Res.Message)"
                                                `$m.severity = 'ERROR'
                                                `$messages = @(`$m)

                                                `$resTmp = "" | select messages
                                                `$resTmp.messages = `$messages
                                                Write-Output `$resTmp
                                            }
                                            else
                                            {
                                                Write-Output `$res
                                            }
                                        }
                                        catch [Exception]
                                        {
                                            `$m = "" | select message,severity
                                            `$m.message = "Data Source '`$(`$this.Name)'. `$(`$_.Exception.Message)"
                                            `$m.severity = 'EXCEPTION'
                                            `$messages = @(`$m)
                                            `$resTmp = "" | select messages
                                            `$resTmp.messages = `$messages
                                            Write-Output `$resTmp
                                            Write-Log -message `$_ -Level EXCEPTION
                                            #Write-Host `$_.Exception.Message
                                        }
"@
                                        $sb = $executioncontext.InvokeCommand.NewScriptBlock($code)
                                        Add-Member -InputObject $out -Name ((Get-Culture).TextInfo.ToTitleCase($oper)) -MemberType ScriptMethod -Value $sb
                                }
                            }
                        }
                        else
                        {
                            Set-StandardMembers -MyObject $out -DefaultProperties Name,Type
                        }
                    
                        Write-Output $out
                    }#foreach ($out in $output)
                }# if ($datasource.items)
            }
            catch [Exception]
            {
                Write-Log -message $_.Exception -Level Error
                Write-Host $_.Message -ForegroundColor Red
            }
        }# foreach


    }# PROCESS

    END
    { 


    }# END

}
Export-ModuleMember -Function Get-WLDatasource