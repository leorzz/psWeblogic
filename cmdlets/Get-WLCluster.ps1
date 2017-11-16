#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLCluster
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(
            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow)]
            [Parameter(ParameterSetName='InputObject')]
                [System.Management.Automation.PSObject]$InputObject,

            [Parameter(Mandatory=$False, HelpMessage="Use AdminServer name.")]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [System.Collections.Generic.List[String]]$Name,

            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use or not the cache for this query.")]
                [Switch]$Cache = $Script:config.parameters.environment.CacheEnable,

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
            try
            {
                foreach ($obj in $InputObject)
                {
                    if ($obj.ResourceType -in ('domain','server'))
                    {
                        if (-not $AdminServer)
                        {
                            $AdminServer = New-Object System.Collections.Generic.List[String]
                        }
                        $null = $AdminServer.Add($obj.AdminServer)
                    }

                    if ($obj.ResourceType -in ('server'))
                    {
                        if (-not $servers)
                        {
                            $servers = New-Object System.Collections.ArrayList
                        }
                        $null = $servers.Add($obj)
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
                $cluster = Invoke-WLResource -AdminServer $admin -Resource clusters -Management:$false -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent

                if ($cluster)
                {
                    if ($Name)
                    {
                        $output = $cluster.items | ? { $_.Name -in $Name }
                    }
                    else
                    {
                        $output = $cluster.items
                    }

                    if ($servers)
                    {
                        $output = $output | ? {$_.Servers.Name | ? {$_ -in $servers.Name} }
                    }


                    foreach ($out in $output)
                    { 
                        Add-Member -InputObject $out -MemberType NoteProperty -Name ResourceType -Value "cluster" 
                        Add-Member -InputObject $out -MemberType NoteProperty -Name AdminServer -Value $admin
                        Set-StandardMembers -MyObject $out -DefaultProperties Name,Servers,AdminServer
                        Write-Output $out
                    }
                }
            
                #Write-Output $output
            }
            catch [Exception]
            {
                Write-Log -message $_ -Level Error
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }#foreach

    }# END

}
Export-ModuleMember -Function Get-WLCluster