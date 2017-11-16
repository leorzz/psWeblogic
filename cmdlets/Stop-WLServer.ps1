#.ExternalHelp ../psWeblogic.Help.xml
function Stop-WLServer
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

            [Parameter(Mandatory=$False, HelpMessage="Use to suspend servers that are running.")]
                [Switch]$SuspendOnly,

            [Parameter(Mandatory=$False, HelpMessage="Use to Specifies whether to gracefully shut down the server (false, the default) or force shut down of the server (true).")]
                [Switch]$Force=$False,

                [Int]$Throttling = 1,
                [int]$TimeoutSec = 900

    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
        Write-Debug "Current CMDLET: $($currentMethod)"
        Write-Debug "IsLastPipe: $($IsLastPipe)"
        #Ignore-SelfSignedCerts

        if ($Throttling -gt 1)
        {
            $sb = {
                    Param($obj,$Credential,$ResourceCacheIndex,$SuspendOnly,$TimeoutSec,$Force)
                    Import-Module psWeblogic; 
                    Repair-WLCacheIndex
                    $obj | Stop-WLServer -Credential $Credential -SuspendOnly:$SuspendOnly -TimeoutSec $TimeoutSec -Force:$Force
                }
        }
        
    }# BEGIN

    PROCESS
    {

        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            try
            {
                if ($InputObject.ResourceType -contains ('Cluster'))
                {
                    $objs = $InputObject | Get-WLServer -Management
                }
                elseif ($InputObject.ResourceType -contains ('Server'))
                {
                    $objs = $InputObject
                }

                foreach ($obj in $objs)
                {
                    if ($obj.ResourceType -in ('server') -and ($obj.Name -ne "AdminServer"))
                    {
                        try
                        {
                            if ($obj.PsObject.Methods.Name -notcontains 'Shutdown')
                            {
                                $isSecure = $obj.Url -match "^https://"
                                $obj = Get-WLServer -AdminServer $obj.AdminServer -Name $obj.Name -Credential $Credential -Management -TimeoutSec $TimeoutSec -SecureConnection:$isSecure
                            }

                            if ($obj.PsObject.Methods.Name -contains 'Shutdown')
                            {
                                if ($Throttling -gt 1)
                                {
                                    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
                                    if ($running.Count -le $Throttling) 
                                    {
                                        $null = Start-Job -Name $obj.Name -ScriptBlock $sb -ArgumentList $obj,$Credential,$Script:ResourceCacheIndex,$SuspendOnly.IsPresent,$TimeoutSec,$Force.IsPresent
                                    }
                                    else 
                                    {
                                         $null = $running | Wait-Job -Any
                                    }

                                    $jobResult = Get-Job | ? {$_.State -eq 'Completed' -and $_.HasMoreData}
                                    $out  = $jobResult | Receive-Job
                                    if ($out)
                                    {
                                        Set-StandardMembers -MyObject $out -DefaultProperties Name,Messages
                                        Write-Output $out
                                    }
                                    $null = $jobResult | Remove-Job
                                }
                                else
                                { 
                                    Add-Member -InputObject $obj -Name Messages -MemberType NoteProperty -Value $null -Force
                                    Add-Member -InputObject $obj -Name Item -MemberType NoteProperty -Value $null -Force

                                    if ($SuspendOnly.IsPresent)
                                    {
                                        $result = $obj.Suspend($TimeoutSec)
                                    }
                                    elseif ($Force.IsPresent)
                                    {
                                        $result = $obj.Shutdown($TimeoutSec,"force=true")
                                    }
                                    else
                                    {
                                        $result = $obj.Shutdown($TimeoutSec)
                                    }


                                    if ($result -is [Exception])
                                    {
                                        $m = "" | select message,severity
                                        $m.message = "Shutdown the server '$($obj.name)'."
                                        $m.message += "$($result.Message)"
                                        $m.severity = 'ERROR'
                                        $messages = @($m)
                                        $Obj.Messages = $messages
                                    }
                                    else
                                    {
                                        $Obj.Messages = $result.messages
                                        $obj.Item = $result.item
                                        $Obj | Add-Member -MemberType NoteProperty -Name Links -Value $obj.links -ErrorAction SilentlyContinue

                                    }

                                    Set-StandardMembers -MyObject $obj -DefaultProperties Name,Messages
                                    Write-Output $obj
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
            }#if ($obj.ResourceType -in ('server') -and ($obj.Name -ne "AdminServer"))
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
                Get-WLServer -AdminServer $admin -Name $Name -Credential $Credential -Management | Stop-WLServer -SuspendOnly:$SuspendOnly.IsPresent
            }
        }

    }# PROCESS

    END
    {
        
        do # Recovering data
        {
            $jobsRunning = Get-Job | ? {$_.State -eq 'Running'}
            $jobsHasMoreData = Get-Job | ? {$_.State -eq 'Completed' -and $_.HasMoreData}
            $out = $jobsHasMoreData | Receive-Job
            if ($out)
            {
                Set-StandardMembers -MyObject $out -DefaultProperties Name,Messages
                Write-Output $out
            }
            $null = $jobsHasMoreData | Remove-Job -Force
            if ($jobsRunning) { Start-Sleep -Seconds 2 }
        }While($jobsRunning)

         
        # Because of the object state change , requests again to server to renew the cache.
        $AdminServer | % { Remove-WLResourceCache -UriMatch  "$($admin).*servers" }
        #$null = Get-WLServer -AdminServer $admin -Name $Name -Credential $Credential -Management -Cache:$False
    }# END

}
Export-ModuleMember -Function Stop-WLServer