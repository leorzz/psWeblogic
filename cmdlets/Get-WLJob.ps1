#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLjob
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.")]
            #[Parameter(ParameterSetName='Admin')]
                [string[]]$AdminServer,

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow,ParameterSetName="InputObject")]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),


            [Parameter(Mandatory=$False, HelpMessage="Use or not the cache for this query.")]
                [Switch]$Cache = $Script:config.parameters.environment.CacheEnable,

                [int]$TimeoutSec = 30

    )

    BEGIN
    {
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
                    if ($obj.ObjType -in ('domain'))
                    {
                        $AdminServer += $obj.AdminServer
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

        foreach ($admin in $AdminServer)
        {
            try
            {
                $resourceJobs = @("/management/wls/latest/jobs/server","/management/wls/latest/jobs/deployment")
                $jobs = $resourceJobs | % {Invoke-WLResource -AdminServer $admin -Resource $_ -Management -Credential $Credential -TimeoutSec $TimeoutSec -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent}
                $output = $jobs.items
                foreach ($out in $output)
                { 
                    $out.beginTime =  Get-EpochDate -epochdate $out.beginTime
                    $out.endTime =  Get-EpochDate -epochdate $out.endTime
                    Add-Member -InputObject $out -MemberType NoteProperty -Name Uri -Value ($job.links | ? {$_.Title -eq $out.id}).Uri
                    Add-Member -InputObject $out -MemberType NoteProperty -Name ObjType -Value "job" 
                    Add-Member -InputObject $out -MemberType NoteProperty -Name AdminServer -Value $AdminServer
                    Set-StandardMembers -MyObject $out -DefaultProperties @('id','operation','status','description')
                }
                Write-Output $output
            }
            catch [Exception]
            {
                Write-Log -message $_.Exception.Message -Level Error
                Write-Host $_ -ForegroundColor Red
            }
        }#foreach
    }# PROCESS

    END
    {

    }# END

}
Export-ModuleMember -Function Get-WLjob