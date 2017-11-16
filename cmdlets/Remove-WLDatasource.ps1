#.ExternalHelp ../psWeblogic.Help.xml
#requires -Version 3 
function Remove-WLDatasource
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use AdminServer name.",ParameterSetName='AdminServer')]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,ParameterSetName='InputObject')]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.",ParameterSetName='AdminServer')]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use to set datasource name.")]
                [string[]]$Name,

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
            Get-WLDatasource -AdminServer $AdminServer -Credential $Credential -Management -Name $Name -SecureConnection:$SecureConnection.IsPresent -TimeoutSec $TimeoutSec | Remove-WLDatasource
        }
        elseif ($PSBoundParameters.ContainsKey('InputObject'))
        {
            if ($Name)
            {
                $InputObject = $InputObject | ? {$_.name -in $Name}
            }

            foreach ($obj in $InputObject)
            {
                if ($obj.ResourceType -in ('datasource'))
                {
                    if ( $obj.PsObject.Properties.Name -contains 'Uri')
                    {
                        $toRemove = $obj
                    }
                    else
                    {
                        $toRemove = Get-WLDatasource -AdminServer $obj.AdminServer -Credential $Credential -Management -Name $obj.name -SecureConnection:$SecureConnection.IsPresent -TimeoutSec $TimeoutSec
                    }

                    if ($toRemove)
                    {
                        try
                        {
                            if ($PSCmdlet.ShouldProcess($toRemove.Name,$currentMethod))
                            {
                                $result = Update-WLResource -AdminServer $toRemove.AdminServer -Credential $Credential -Uri $toRemove.Uri -Method Delete
                                Remove-WLResourceCache -UriMatch "$($toRemove.AdminServer).*datasources"
                                Write-Output $result
                            }
                        }
                        catch [Exception]
                        {
                            Write-Log -message $_.Exception -Level Error
                            Write-Host $_.Message -ForegroundColor Red
                        }
                    }#if ($toRemove)
                }
                else
                {
                    Write-Host InputObject is invalid. Use a datasource type object. -ForegroundColor Red
                }
            } #foreach ($obj in $InputObject)
        } #if ($PSBoundParameters.ContainsKey('InputObject'))


    }# PROCESS

    END
    { 

    }# END

}

Export-ModuleMember -Function Remove-WLDatasource