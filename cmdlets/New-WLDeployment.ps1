#.ExternalHelp ../psWeblogic.Help.xml
function New-WLDeployment
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]
     #[CmdletBinding(DefaultParameterSetName='ParameterSet1', 
     #             SupportsShouldProcess=$true, 
     #             PositionalBinding=$false
     #             #HelpUri = 'http://www.microsoft.com/',
     #             #ConfirmImpact='Medium'
     #             )]
     #[OutputType([String])]
    param(
            [Parameter(Mandatory=$False, HelpMessage="Use the AdminServer target.", ParameterSetName="AdminServer")]
                [System.Collections.Generic.List[String]]$AdminServer,

            [Parameter(Mandatory=$False, HelpMessage="Use a application name.")]
                [string]$Name,

            [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
                [System.Management.Automation.PSObject]$InputObject,
            
            [Parameter(Mandatory=$False, HelpMessage="Use PSCredential object.")]
                [System.Management.Automation.PSCredential]$Credential = (Get-WLCredential -Alias Default),

            [Parameter(Mandatory = $False, HelpMessage="Use 'application' or 'library'.")]
            [ValidateSet("application","library")]
                [String]$Type = "application",

            [Parameter(Mandatory=$False, HelpMessage="Use to define SSL/TLS connections.")]
                [Switch]$SecureConnection = $True,

            [Parameter(Mandatory=$False, HelpMessage="Use the deployment FullPath.")]
                [String[]]$DeploymentPath,

            [Parameter(Mandatory=$False, HelpMessage="Use the package file path.")]
                [String]$InFile,

            [Parameter(Mandatory=$False, HelpMessage="Use the targets to deployment.")]
                [String[]]$Targets,

                [int]$TimeoutSec = 30
    )

    BEGIN
    {
        $currentMethod = (Get-PSCallStack)[0].Command
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition

        # https://docs.oracle.com/cd/E13222_01/wls/docs100/deployment/deployunits.html#wp1047997


        function New-FormData
        {
            Param($InFile,$Boundary,$Model)
            $header = @{"Accept" = "application/json"; "X-Requested-By" = "MyClient"}
            $fileBytes = [IO.File]::ReadAllBytes($InFile)
            $fileDataAsString = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)

            #$Boundary = [System.Guid]::NewGuid().ToString() 
            $bodyLines = @()
            $bodyLines += "--$Boundary"
            $bodyLines += "Content-Disposition: form-data; name=`"model`""
            $bodyLines += ""
            $bodyLines += $($Model)
            $bodyLines += "--$Boundary"
            $bodyLines += "Content-Disposition: form-data; name=`"deployment`"; filename=`"$(Split-Path $InFile -Leaf)`""
            $bodyLines += "Content-Type: application/octet-stream"
            $bodyLines += ""
            $bodyLines += $fileDataAsString
            $bodyLines += "--$Boundary--"
            $bodyLines = $bodyLines -join "`r`n"
            $bodyLines
        }

    }# BEGIN

    PROCESS
    {
        # http://buttso.blogspot.com.br/2015/04/deploying-applications-remotely-with.html 
        $toDeploys = @()
        if ($InputObject)
        {
            foreach ($obj in $InputObject)
            {
                try
                {
                    if ($obj.PsObject.Properties.Name -contains 'AdminServer')
                    {
                        $AdminServer = $obj.AdminServer
                        if ($obj.ResourceType -in ('Target','Cluster','Server'))
                        {
                            if ($Targets)
                            {
                                Write-Verbose "The target '$($Targets -join ',')' has been changed by the input object '$($obj.name)'"
                            }
                            [Array]$appTargets = $obj.name

                            
                            if ($InFile)
                            {
                                $deploy = "" | select name,targets
                                if ($Name)
                                {
                                    $deploy.name = $Name
                                }
                                else
                                {
                                    $deploy.name = [io.path]::GetFileNameWithoutExtension($InFile)
                                }
                                $deploy.targets = @($obj.name)
                            }
                            else
                            {
                                $deploy = "" | select name,targets,deploymentPath
                                if ($DeploymentPath)
                                {
                                    $deploy.deploymentPath = $DeploymentPath
                                }
                                else
                                {
                                    Read-Host "Type the $($Type) name: " -OutVariable path
                                    if (-not (Test-Path $path -IsValid) )
                                    {
                                        Write-Host "Invalid path $($path). Aborted." -ForegroundColor Cyan
                                        break
                                    }
                                }
                            }

                        }
                        elseif ( ($obj.ResourceType -in ('Deployment')) -and ($obj.PsObject.Properties.Name -contains 'deploymentpath') )
                        {
                            if (Test-Path -Path $obj.deploymentpath)
                            {
                                $deploy = "" | select name,targets
                                if ($Name)
                                {
                                    $deploy.name = $Name
                                }
                                else
                                {
                                    $deploy.name = [io.path]::GetFileNameWithoutExtension($obj.deploymentpath)
                                }

                                if ($Targets)
                                {
                                    Write-Verbose "The target '$($Targets -join ',')' has been changed by the input object '$($obj.name)'"
                                    $deploy.targets = $Targets
                                }
                                else
                                {
                                    $deploy.targets = @($obj.name)
                                }

                            }
                            else
                            {
                                Write-Host "The path $($obj.deploymentpath) is not available."
                                continue
                            }
                        }
                    }
                    $toDeploys += $deploy
                }
                catch [Exception]
                {
                    Write-Log -message $_.Exception -Level EXCEPTION
                    Write-Host $_.Exception.Message
                }
            }
        }
        else
        {
            if (-not $Targets)
            {
                if (Read-Host -Prompt "Type the Target: " -OutVariable target)
                {
                    $Targets = @($target)
                }
                else
                {
                    Write-Host "The 'Target' was not especified." -ForegroundColor Red
                    break
                }
            }

            $isTarget = Get-WLTarget -AdminServer $AdminServer -Name $Targets

            if ($isTarget)
            {
                if ($DeploymentPath)
                {
                    $DeploymentPath | % {
                        $deploy = "" | select name,targets,deploymentPath
                        $deploy.deploymentPath = $_
                        $deploy.name = [io.path]::GetFileNameWithoutExtension($deploy.deploymentPath)
                        [Array]$deploy.Targets = $Targets
                        $toDeploys += $deploy
                    }

                }
                elseif ($InFile)
                {
                    $deploy = "" | select name,targets
                    $deploy.name = [io.path]::GetFileNameWithoutExtension($InFile)
                }    
                else
                {
                    Write-Host "The 'DeploymentPath' or 'InFile' were not especified." -ForegroundColor Cyan
                    break
                }

                if ($Targets)
                {
                    $deploy.targets = $Targets
                }
                else
                {
                    $deploy.targets = @()
                }

                $toDeploys += $deploy
            }
            else
            {
                Write-Host "Target $($Targets | ConvertTo-Json -Compress) is invalid." -ForegroundColor Cyan
            }
        }


        foreach ($toDeploy in $toDeploys)
        {
            try
            {

                if ($InFile)
                {
                    $boundary = [System.Guid]::NewGuid().ToString() 
                    $header = @{"Accept"="application/json";'Content-Type'="multipart/form-data; boundary=$($boundary)";"X-Requested-By"="MyClient"}
                    $body = New-FormData -InFile $InFile -Boundary $boundary -Model ($toDeploy | ConvertTo-Json -Compress)
                    $deployed = Update-WLResource -AdminServer $AdminServer -Resource $Type -Header $header -Body $body `
                        -Credential $Credential -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent

                    if ($deployed.ErrorDetails)
                    {
                        try
                        {
                            $msg = $deployed.ErrorDetails | ConvertFrom-Json -ErrorAction SilentlyContinue
                            if ($msg)
                            {
                                $split = $msg.messages.message -split "`""
                                if ($split)
                                {
                                    $toDeploy.name = $split[$split.Count - 2].Trim()
                                    $body = New-FormData -InFile $InFile -Boundary $boundary -Model ($toDeploy | ConvertTo-Json -Compress)
                                    $deployed = Update-WLResource -AdminServer $AdminServer -Resource $Type -Header $header -Body $body `
                                        -Credential $Credential -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent
                                }
                                else
                                {
                                    Write-Host $deployed.ErrorDetails -ForegroundColor Red
                                    continue
                                }
                            }
                        }
                        catch [Exception]
                        {
                            Write-Host $_.Exception.Message -ForegroundColor Red
                            Write-Host $deployed.ErrorDetails -ForegroundColor Red
                            Write-Log -message $_.Exception.Message -Level Error
                            continue
                        }

                    }
                }
                else
                {
                    $body = $toDeploy | ConvertTo-Json -Compress
                    $deployed = Update-WLResource -AdminServer $AdminServer -Resource $Type -Header $header -Body $body `
                        -Credential $Credential -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent

                    if ($deployed.ErrorDetails)
                    {
                        try
                        {
                            $msg = $deployed.ErrorDetails | ConvertFrom-Json -ErrorAction SilentlyContinue
                            if ($msg)
                            {
                                $split = $msg.messages.message -split "`""
                                if ($split)
                                {
                                    $toDeploy.name = $split[$split.Count - 2].Trim()
                                    $body = $toDeploy | ConvertTo-Json -Compress
                                    $deployed = Update-WLResource -AdminServer $AdminServer -Resource $Type -Body $body -InFile $InFile -Credential $Credential -TimeoutSec $TimeoutSec -SecureConnection:$SecureConnection.IsPresent
                                }
                                else
                                {
                                    Write-Host $deployed.ErrorDetails -ForegroundColor Red
                                    continue
                                }
                            }
                        }
                        catch [Exception]
                        {
                            Write-Host $_.Exception.Message -ForegroundColor Red
                            Write-Host $deployed.ErrorDetails -ForegroundColor Red
                            Write-Log -message $_.Exception.Message -Level Error
                            continue
                        }

                    }

                }
                Remove-WLResourceCache -UriMatch "$($toRemove.AdminServer).*deployments"
                Set-StandardMembers -MyObject $deployed -DefaultProperties messages,item
                Write-Output $deployed
            }
            catch [Exception]
            {
                Write-Log -message $_.Exception.Message -Level Error
                Write-Host $_ -ForegroundColor Red
            }
        }

    }# PROCESS

    END
    { 

    }# END

}

Export-ModuleMember New-WLDeployment