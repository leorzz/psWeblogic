
$Script:mInfo = $MyInvocation.MyCommand.ScriptBlock.Module


# Store websession to next pipeline
$Script:session = New-Object System.Collections.ArrayList
$Script:domainsInfo = New-Object System.Collections.ArrayList

# Store index to cache (if enable at parameters.json)
$Script:ResourceCacheIndex = New-Object System.Collections.ArrayList



#region OsPlatform
    if ($env:PATH -match "^/")
    {
        $Script:platform = "Unix"
        $Script:appdata = Join-Path -Path $env:HOME -ChildPath ".$($Script:mInfo.Name)"

    }
    else
    {
        $Script:platform = "Windows"
        $Script:appdata = Join-Path -Path $env:APPDATA -ChildPath $Script:mInfo.Name
    }

    if ( -not (Test-Path -LiteralPath $Script:appdata -PathType Container) )
    {
        New-Item -Path $Script:appdata -ItemType Directory -Force
    }
#endregion OsPlatform


$parametersPath = Join-Path -Path $Script:appdata -ChildPath parameters.json
if ( -not (Test-Path -LiteralPath $parametersPath) )
{
    $param = Get-Content -LiteralPath (Join-Path -Path (Join-Path -Path $Script:mInfo.ModuleBase -ChildPath environment) -ChildPath parameters_template.json) | ConvertFrom-Json
    $param.parameters.Environment.DomainsInfoPath = Join-Path -Path $Script:appdata -ChildPath inventory.json
    $param.parameters.Environment.DomainsInfoPathPublish = Join-Path -Path $Script:appdata -ChildPath inventory.json
    $param | ConvertTo-Json | Set-Content -LiteralPath $parametersPath
}

# Store generic config retrieve from parameters.json
$Script:config = (Get-Content -LiteralPath $parametersPath -ErrorAction Stop) -join "`n" | ConvertFrom-Json

if ( ($Script:config.parameters.environment.DomainsInfoPath -match "^([a-zA-Z]:\\|\\\\|FileSystem::\\|/)") -and (-not (Test-Path -LiteralPath $Script:config.parameters.environment.DomainsInfoPath)) )
{
    Copy-Item -LiteralPath (Join-Path -Path (Join-Path -Path $Script:mInfo.ModuleBase -ChildPath environment) -ChildPath inventory_template.json) `
                -Destination $Script:config.parameters.environment.DomainsInfoPath
}


if ($Script:config.parameters.environment.DebugEnable)
{
    $DebugPreference = "Continue"
}
else
{
    $DebugPreference = "SilentlyContinue"
}


#region Include
Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 | ? {$_.Name -notmatch "^_"} | % { . $_.FullName }
Get-ChildItem -Path (Join-Path $PSScriptRoot common) -Filter *.ps1 | ? {$_.Name -notmatch "^_"} | % { . $_.FullName }
Get-ChildItem -Path (Join-Path $PSScriptRoot cmdlets) -Filter *.ps1 | ? {$_.Name -notmatch "^_"} | % { . $_.FullName }


# Store AdminServer information retrieve from 'DomainsInfoPath' property value source.
$Script:resources = (Get-Content -LiteralPath $(Join-Path $PSScriptRoot environment\resources.json) -ErrorAction Stop) -join "`n" | ConvertFrom-Json
foreach ($resource in $Script:resources)
{
    try
    {
        $resource.info.version = $resource.info.version | % { [Version]$_ }
    }
    catch
    {
        Write-Log -message $_.Exception -Level Error
    }
}


#region Force parameter to ignore SSL errors

<#
    # https://connect.microsoft.com/PowerShell/feedback/details/419466/new-webserviceproxy-needs-force-parameter-to-ignore-ssl-errors
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    # Prevent 'The underlying connection was closed'
    # https://alexandrebrisebois.wordpress.com/2014/09/05/powershell-invoke-restmethod-the-underlying-connection-was-closed/
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

function Ignore-SelfSignedCerts {
    add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}#function
#>

#endregion Force parameter to ignore SSL errors


# Optional commands to create a public alias for the function
#New-Alias -Name gdomai -Value Get-Foo
#Export-ModuleMember -Alias aliasFoo




