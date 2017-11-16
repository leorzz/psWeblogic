#.ExternalHelp ../psWeblogic.Help.xml
function Remove-WLDomain
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]

    param(
            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.",ParameterSetName="AdminServer")]
                [System.Collections.Generic.List[String]]$AdminServer=$null,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow,ParameterSetName="InputObject")]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.",ParameterSetName='AdminServer')]
                [Switch]$SecureConnection = $True,

                [int]$TimeoutSec = 30
    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
        $domainsInfoPathPublish =$Script:config.parameters.Environment.DomainsInfoPathPublish
        $domains_backup = $domains = Get-WLDomain -Cache:$False
        $domain_removed = @()
    }# BEGIN

    PROCESS
    {
        if ($AdminServer)
        {
            $domains = $domains | ? AdminServer -ne $AdminServer
            $domain_removed += $domains_backup | ? AdminServer -eq $AdminServer
        }
        elseif ($PSBoundParameters.ContainsKey('InputObject'))
        {
            $domains = $domains | ? AdminServer -NotIn $InputObject.AdminServer
            $domain_removed += $domains_backup | ? AdminServer -In $InputObject.AdminServer
        }
        
    }# PROCESS

    END
    {
        if ($domain_removed)
        {
            $domains_backup | % {
                        $_.Version = $_.Version.ToString();
            } 
            $domains_backup | Select * -ExcludeProperty ResourceType | Sort-Object -Property AdminServer | ConvertTo-Json -Depth 10 | Out-File -LiteralPath "$($domainsInfoPathPublish).bak" -Encoding ascii -Force
            $domains | % {
                        $_.Version = $_.Version.ToString();
            } 
            $domains | Select * -ExcludeProperty ResourceType | Sort-Object -Property AdminServer | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $domainsInfoPathPublish -Encoding ascii -Force
            Write-Host The items below have been excluded. -ForegroundColor Red
            Write-Output $domain_removed
            Write-Host The items above have been excluded. -ForegroundColor Red
        }
    }# END

}

Export-ModuleMember -Function Remove-WLDomain