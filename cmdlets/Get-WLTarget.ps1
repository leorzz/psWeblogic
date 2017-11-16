#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLTarget
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param(

            [Parameter(Mandatory=$False, HelpMessage="Use managedServer name.")]
                [string[]]$AdminServer,

            [Parameter(Mandatory=$False, Position = 1, HelpMessage="Use managedServer name. (regex)")]
                [string[]]$Name = $null,

           [Parameter(Mandatory=$False,ValueFromPipeline=$True,DontShow)]
                [System.Management.Automation.PSObject]$InputObject,
           
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory = $False, HelpMessage="Use 'cluster' or 'server'." )]
            [ValidateSet("cluster","server")]
                [String]$Type = $null,

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use or not the cache for this query.")]
                [Switch]$Cache = $Script:config.parameters.environment.CacheEnable,

            [Parameter(Mandatory = $False, DontShow, HelpMessage="Use to access management features.")]
                [Switch]$Management=$True,

                [int]$TimeoutSec = 30    
        )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $supportedVersionAPI = @('12.1.3')
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
        $inObj = New-Object -TypeName System.Collections.ArrayList
    }# BEGIN

    PROCESS
    {
        if ($PSBoundParameters.ContainsKey('InputObject'))
        {
            foreach ($obj in $InputObject)
            {
                if ($obj.ResourceType -in ('Domain'))
                {
                    $AdminServer = $InputObject | select -ExpandProperty AdminServer
                }
                elseif ($obj.ResourceType -in ('Deployment','Datasource'))
                {
                    $AdminServer = $InputObject | select -ExpandProperty AdminServer
                    #$null = $inObj.Add($InputObject)
                }

            }
        }

        foreach ($admin in $AdminServer)
        {
            try
            {

                $target = Invoke-WLResource -AdminServer $admin -Resource targets -Credential $Credential -TimeoutSec $TimeoutSec -Management:$Management.IsPresent -ErrorAction SilentlyContinue -Cache:$Cache.IsPresent -SecureConnection:$SecureConnection.IsPresent
                
                if ($target.items)
                {
                    $output = $target.items
                    if ($InputObject)
                    {
                     
                        if ($InputObject[0].ResourceType -eq "Datasource")
                        {
                            if ($InputObject[0].PsObject.Properties.Name -contains 'targets')
                            {
                                $output = $output | ? { $_.Name -in $InputObject.targets }
                            }
                            else
                            {
                                $output = $output | ? { $_.Name -in $InputObject.instances.server }
                            }
                        }
                        elseif ($InputObject[0].ResourceType -eq "Deployment")
                        {
                            if ($InputObject[0].PsObject.Properties.Name -contains 'targets')
                            {
                                $output = $output | ? { $_.Name -in $InputObject.targets }
                            }
                            else
                            {
                                $depl = Get-WLDeployment -AdminServer $admin -Name $InputObject.name -Management -Credential $Credential -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent -ErrorAction Stop
                                #$depl = $depl | ? { $_.name -eq $inObj.name }
                                $output = $output | ? { $_.Name -in $depl.targets }
                            }
                        }

                    }

                    if ($Name)
                    {
                        $output = $output | ? { $_.name -in $Name }
                    }

                    if ($type)
                    {
                        $output = $output | ? { $_.type -eq $type }
                    }


                    foreach ($out in $output)
                    { 
                        Add-Member -InputObject $out -MemberType NoteProperty -Name AdminServer -Value $admin
                        Add-Member -InputObject $out -MemberType NoteProperty -Name ResourceType -Value 'Target'
                        if ($Management.IsPresent)
                        {
                            Set-StandardMembers -MyObject $out -DefaultProperties Name,Type,AdminServer
                        }
                        else
                        {
                        }
                    }
                    $output = $output | Sort-Object -Property AdminServer,Type,Name
                    Write-Output $output
                }
            }
            catch [Exception]
            {
                Write-Log -message $_ -Level Error
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }#foreach
    }# PROCESS

    END
    {

    }# END

}
Export-ModuleMember -Function Get-WLTarget