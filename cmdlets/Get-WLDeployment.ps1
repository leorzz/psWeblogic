#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLDeployment
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.",ParameterSetName="AdminServer")]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [string[]]$Name,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow,ParameterSetName="InputObject")]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory = $False, HelpMessage="Use 'application' or 'library'.")]
            [ValidateSet("application","library")]
                [String]$Type = $nul,

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
                    $targets = $InputObject
                }
                elseif ($InputObject.ResourceType -in ('Deployment'))
                {
                    if (-not $Name)
                    {
                        $Name = $InputObject.Name
                    }
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
                if ($Type)
                {
                    if ($Management.IsPresent)
                    {
                        $resource = $Type
                    }
                    else
                    {
                        $resource = "deployments"
                        Write-Host Type $Type is only supported in 'management' mode. -ForegroundColor Cyan
                    }
                }
                else
                {
                    $resource = "deployments"
                }
                $deployment = Invoke-WLResource -AdminServer $admin -Resource $resource -Credential $Credential -Management:$Management.IsPresent -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                if ($deployment.items)
                {
                    $output = $deployment.items
                    if ($name)
                    {
                        $output = $output | ? { $_ | ? {$_.name -in $Name} }
                    }

                    if ($targets)
                    {
                        if ($Management.IsPresent)
                        {
                            $output = $output | ? { $_.targets | ? {$_ -in $targets.name} }
                        }
                        else
                        {
                            $depl = Invoke-WLResource -AdminServer $admin -Resource $resource -Credential $Credential -Management -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                            $depl = $depl | ? { $_.targets | ? {$_ -in $targets.name} }
                            $output = $output | ? {$_.name -in $depl.name}
                        }
                    }

                    $wl_domain = Get-WLDomain -AdminServer $admin | select -First 1
                    $operations = $Script:resources | ? { ($_.info.version -eq $wl_domain.Version) } | select -ExpandProperty operation
                    foreach ($out in $output)
                    { 
                        Add-Member -InputObject $out -MemberType NoteProperty -Name AdminServer -Value $admin
                        Add-Member -InputObject $out -MemberType NoteProperty -Name ResourceType -Value "Deployment" 
                        if ($Management.IsPresent)
                        {
                            Add-Member -InputObject $out -MemberType NoteProperty -Name Credential -Value $Credential
                            Add-Member -InputObject $out -MemberType NoteProperty -Name Uri -Value ($deployment.links | ? {$_.Title -eq $out.Name}).Uri
                            Set-StandardMembers -MyObject $out -DefaultProperties Name,Type,State
                            #=========================================================================================
                            #=========================================================================================
                            if ($operations.$($out.type).Lifecycle)
                            {
                                $operations.application.Lifecycle | % {
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
                        else
                        {
                            Set-StandardMembers -MyObject $out -DefaultProperties Name,Type,State
                        }
                    
                        Write-Output $out
                    }#foreach ($out in $output)
                }
            }
            catch [Exception]
            {
                Write-Log -message $_.Exception.Message -Level Error
                Write-Host $_ -ForegroundColor Red
            }
        }# foreach



    }# PROCESS

    END
    { 

    }# END

}

Export-ModuleMember -Function Get-WLDeployment