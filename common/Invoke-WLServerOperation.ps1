function Invoke-WLServerOperation
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(
            [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
            [Parameter(ParameterSetName='InputObject')]
                [System.Management.Automation.PSObject]$InputObject,

            [Parameter(Mandatory=$False, HelpMessage="Use AdminServer name.")]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.")]
                [System.Collections.Generic.List[String]]$Name,

            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use to start servers at asynchronous mode.")]
                [Switch]$AsJob,

            [Parameter(Mandatory=$False)]
                [String]$Operation,

                [int]$TimeoutSec = 30

    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
        #Ignore-SelfSignedCerts

        if ($AsJob.IsPresent)
        {
            $sb = {
                    Param($AdminServer,$Name,$Credential,$ResourceCacheIndex,$Operation)
                    Import-Module psWeblogic; 
                    Repair-WLCacheIndex
                    Invoke-WLServerOperation -AdminServer $AdminServer -Name $Name -Credential $Credential -Operation $Operation
                }
        }
        
    }# BEGIN

    PROCESS
    {

        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            try
            {
                foreach ($obj in $InputObject)
                {
                    
                    if ($obj.ResourceType -in ('server') -and ($obj.Name -ne "AdminServer"))
                    {
                        try
                        {
                            if ($obj.Tenant -eq 'management')
                            {

                                if ($AsJob.IsPresent)
                                {
                                    #$Script:ResourceCacheIndex | ConvertTo-Json -Compress | Out-File -LiteralPath (Join-Path $env:TEMP 'ResourceCacheIndex.JSON')
                                    $jobResult = Get-Job | ? {$_.State -eq 'Completed' -and $_.HasMoreData}
                                    $jobResult | Receive-Job
                                    $null = $jobResult | Remove-Job
                                    $null = Start-Job -Name $obj.Name -ScriptBlock $sb -ArgumentList $obj.AdminServer,$obj.Name,$Credential,$Script:ResourceCacheIndex,$Operation
                                }
                                else
                                {  
                                    Switch ($Operation)
                                    {   
                                        Start
                                            {                           
                                                $result = $obj.Start($TimeoutSec)
                                                if ($result)
                                                {
                                                    Write-Output $result
                                                }
                                                else
                                                {
                                                    $result = $obj.Resume($TimeoutSec)
                                                    Write-Output $result
                                                }
                                            }
                                        Shutdown
                                                {                           
                                                    $result = $obj.Shutdown($TimeoutSec)
                                                    if ($result)
                                                    {
                                                        Write-Output $result
                                                    }
                                                }
                                        Restart
                                                {                           
                                                    $result = $obj.Restart($TimeoutSec)
                                                    if ($result)
                                                    {
                                                        Write-Output $result
                                                    }
                                                }
                                        Default { Write-Host 'Operatiom not available.' }
                                    }
                                }
                            }
                        }
                        catch [Exception]
                        {
                            Write-Log -message $_ -Level EXCEPTION
                            Write-Host $_.Exception.Message
                        }
                        
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
        else
        {
            foreach ($admin in $AdminServer)
            {
                Get-WLServer -AdminServer $admin -Name $Name -Credential $Credential -Tenant management | Start-WLServer -AsJob:$AsJob.IsPresent
            }
        }

    }# PROCESS

    END
    {
        do # Recovering data
        {
            $jobsRunning = Get-Job | ? {$_.State -eq 'Running'}
            $jobsHasMoreData = Get-Job | ? {$_.State -eq 'Completed' -and $_.HasMoreData}
            Write-Output ($jobsHasMoreData | Receive-Job)
            $null = $jobsHasMoreData | Remove-Job -Force
            if ($jobsRunning) { Start-Sleep -Seconds 2 }
        }While($jobsRunning)

         
        if ($result)
        {
            # Because of the object state change , requests again to server to renew the cache.
            $AdminServer | % { Remove-WLResourceCache -UriMatch  "$($admin).*servers" }
            #$null = Get-WLServer -AdminServer $admin -Name $Name -Credential $Credential -Tenant management -Cache:$False
        }
    }# END

}