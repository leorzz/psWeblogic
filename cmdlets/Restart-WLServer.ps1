#.ExternalHelp ../psWeblogic.Help.xml
function Restart-WLServer
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
            [Parameter(Mandatory=$False, ParameterSetName='InputObject', ValueFromPipeline=$True,DontShow)]
                [System.Management.Automation.PSObject]$InputObject,

            [Parameter(Mandatory=$False, ParameterSetName="AdminServer", HelpMessage="Use AdminServer name.")]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, ParameterSetName="AdminServer", HelpMessage="Use managedServer name.")]
                [System.Collections.Generic.List[String]]$Name,

            [Parameter(Mandatory=$False, ParameterSetName="AdminServer", HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, ParameterSetName="AdminServer", HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to Specifies whether to gracefully shut down the server (false, the default) or force shut down of the server (true).")]
                [Switch]$Force=$False,

            #[Parameter(Mandatory=$False, HelpMessage="Use to Specifies whether to gracefully shut down the server (false, the default) or force shut down of the server (true).")]
            #    [Switch]$Detached=$False,

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
                    Param($Credential,$TimeoutSec,$Force)
                    Import-Module psWeblogic; 
                    Repair-WLCacheIndex
                    $Input[0] | Restart-WLServer -Force:$Force -TimeoutSec $TimeoutSec
                    #Restart-WLServer -AdminServer $Input[0].AdminServer -Name $Input[0].Name -Credential $Credential -TimeoutSec $TimeoutSec  | ConvertTo-Json | Out-File -FilePath D:\_work\temp\teste1.txt
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
                            $isSecure = $obj.Url -match "^https://"
                            if ($obj.PsObject.Methods.Name -notcontains 'Restart')
                            {
                                $obj = Get-WLServer -AdminServer $obj.AdminServer -Name $obj.Name -Credential $Credential -Management -TimeoutSec $TimeoutSec -SecureConnection:$isSecure
                            }

                            if ($obj.PsObject.Methods.Name -contains 'Restart')
                            {
                                if ($Throttling -gt 1)
                                {
                                    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
                                    if ($running.Count -le $Throttling) 
                                    {
                                         #$null = Start-Job -Name $obj.Name -ScriptBlock $sb_force -ArgumentList $obj.AdminServer,$obj.Name,$Credential,$Script:ResourceCacheIndex,$TimeoutSec,$Force.IsPresent
                                         $null = Start-Job -Name $obj.Name -ScriptBlock $sb -InputObject $obj -ArgumentList $Credential,$TimeoutSec,$Force.IsPresent
                                         
                                    }
                                    else 
                                    {
                                         $running | Wait-Job -Any
                                    }

                                    $jobResult = Get-Job | ? {$_.State -eq 'Completed' -and $_.HasMoreData}
                                    $out  = $jobResult | Receive-Job
                                    if ($out)
                                    {
                                        Set-StandardMembers -MyObject $out -DefaultProperties Name,Messages
                                        Write-Output $out
                                    }
                                    $null = $jobResult | Remove-Job -Force
                                }
                                else
                                { 
                                    if (-not $PSBoundParameters.ContainsKey('Messages'))
                                    {
                                        Add-Member -InputObject $obj -Name Messages -MemberType NoteProperty -Value $null -Force
                                    }
                                    if (-not $PSBoundParameters.ContainsKey('Item'))
                                    {
                                        Add-Member -InputObject $obj -Name Item -MemberType NoteProperty -Value $null -Force
                                    }


                                    
                                    
                                    $queryParameters = New-Object System.Collections.ArrayList
                                    #if ($Detached.IsPresent)
                                    #{
                                    #    $null =  $queryParameters.Add("_detached=true")
                                    #}
                                    if ($Force.IsPresent)
                                    {
                                        $null = $queryParameters.Add("force=true")
                                    }

                                    if ($queryParameters)
                                    {
                                        $result = $obj.Shutdown($TimeoutSec,$queryParameters)
                                    }
                                    $result = $obj.Restart($TimeoutSec)

                                    if ($result -is [Exception])
                                    {
                                        $m = "" | select message,severity
                                        $m.message = "Restart the server '$($obj.name)'."
                                        $m.message += "$($result.Message)"
                                        $m.severity = 'ERROR'
                                        $messages = @($m)
                                        $Obj.Messages = $messages
                                    }
                                    else
                                    {
                                        $msg = $result.messages | select *
                                        if ($Force.IsPresent)
                                        {
                                            $msg.message = "(Force)$($msg.message)"
                                        }
                                        $Obj.Messages = $msg
                                        $obj.Item = $result.item
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
                Get-WLServer -AdminServer $admin -Name $Name -Credential $Credential -Management -TimeoutSec $TimeoutSec `
                    | Restart-WLServer -TimeoutSec $TimeoutSec
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
Export-ModuleMember -Function Restart-WLServer