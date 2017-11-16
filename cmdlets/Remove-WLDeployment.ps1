#.ExternalHelp ../psWeblogic.Help.xml
function Remove-WLDeployment
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.",ParameterSetName="AdminServer")]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name.")]
                [string[]]$Name,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow,ParameterSetName="InputObject")]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.",ParameterSetName='AdminServer')]
                [Switch]$SecureConnection = $True,

                [int]$TimeoutSec = 30
    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
    }# BEGIN

    PROCESS
    {
        if ($Name -and $AdminServer)
        {
            $DeploymentsToRemove = Get-WLDeployment -AdminServer $AdminServer -Name $Name -Management -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent
        }
        elseif ($PSBoundParameters.ContainsKey('InputObject'))
        {
            if ($Name)
            {
                $InputObject = $InputObject | ? {$_.name -in $Name}
            }

            foreach ($obj in $InputObject)
            {
                if ($obj.ResourceType -in ('Deployment'))
                {
                    if ( $obj.PsObject.Properties.Name -contains 'Uri')
                    {
                        $toRemove = $obj
                    }
                    else
                    {
                        $toRemove = Get-WLDeployment -AdminServer $obj.AdminServer -Credential $Credential -Management -Name $obj.name -SecureConnection:$SecureConnection.IsPresent -TimeoutSec $TimeoutSec
                    }

                    if ($toRemove)
                    {
                        try
                        {
                            if ($PSCmdlet.ShouldProcess($toRemove.Name,$currentMethod))
                            {
                                $result = Update-WLResource -Uri $toRemove.Uri -Method Delete -AdminServer $toRemove.AdminServer -Credential $Credential -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent
                                Remove-WLResourceCache -UriMatch "$($toRemove.AdminServer).*deployments"
                                Write-Output $result
                            }
                        }
                        catch [Exception]
                        {
                            Write-Log -message $_.Exception.Message -Level Error
                            Write-Host $_ -ForegroundColor Red
                        }
                    }#if ($toRemove)
                }
            }
        }

    }# PROCESS

    END
    { 

    }# END

}

Export-ModuleMember -Function Remove-WLDeployment