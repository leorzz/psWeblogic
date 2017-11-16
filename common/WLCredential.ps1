# http://www.powershellmagazine.com/2012/10/30/pstip-storing-of-credentials/
#region PSTip Storing of credentials

    #.ExternalHelp ../psWeblogic.Help.xml
    function New-WLCredential
    {
        [CmdletBinding()]
 
        param(
            [Parameter(Mandatory = $false, Position = 0 )]
                [string]$UserName,
            [Parameter(Mandatory = $false, Position = 1)]
                [SecureString]$Password,
            [Parameter(Mandatory = $true, Position = 2)]
            [Alias('Alias')]
                [string]$Name,
            [Parameter(Mandatory = $false)]
                #[String]$Path = (Join-Path -Path $Script:mInfo.ModuleBase -ChildPath security),
                [String]$Path = (Join-Path -Path $Script:appdata -ChildPath security),
                [Switch]$Force
        )
 
        if ( (Test-Path (Join-Path -Path $Path -ChildPath $Name)) -and (-not $Force.IsPresent))
        {
            Write-Host "Aborted. This WLCredential Alias '$($Name)' already exists. Use '-Force' switch to overwrite." -ForegroundColor Cyan
            return
        }
 
        # get credentials for given username
        if ($UserName -and $Password)
        {
            $cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)
        }
        elseif ($UserName)
        {
            $cred = Get-Credential -UserName $UserName -Message "Enter the credetial for the $($Name) alias."
        }
        else
        {
            $cred = Get-Credential -Message "Enter the credetial for the credential name $($Name)."
        }

        # and save encrypted text to a file
        if ($cred)
        {
            if (-not (Test-Path $Path))
            {
                New-Item -Path $Path -ItemType directory -Force
            }
            $credential = "" | select UserName,Password
            $credential.UserName = $cred.UserName
            $credential.Password = $cred.Password | ConvertFrom-SecureString
            $credential | ConvertTo-Json | Out-File -FilePath (Join-Path -Path $Path -ChildPath $Name)
            #Remove-Variable -Name cred
            #Remove-Variable -Name credential
            return Get-WLCredential -Alias $Name
        }
    }
 
    $script:NotCredSave = @()
    #.ExternalHelp ../psWeblogic.Help.xml
    function Get-WLCredential
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false,Position = 0)]
            [Alias('Alias')]
                [string]$Name,
            [Parameter(Mandatory = $false)]
                [String]$Path = (Join-Path -Path $Script:appdata -ChildPath security)
        )
        try
        {
            if ($Name)
            {
                $credentials_files = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | ? { $_.Name -match $Name }
            }
            else
            {
                $credentials_files = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
            }
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $null
        }

        if ($credentials_files)
        {
            $credentials_files | % {
                try
                {
                    $credential = (Get-Content -Path $_.FullName) -join "`n" | ConvertFrom-Json
                    $item = New-Object System.Management.Automation.PSCredential $credential.UserName, ($credential.Password | ConvertTo-SecureString)
                    Add-Member -InputObject $item -Name Name -MemberType NoteProperty -Value $_.Name
                    Add-Member -InputObject $item -Name CreationTime -MemberType NoteProperty -Value $_.CreationTime
                    Write-Output $item
                }
                catch
                {
                    Write-Log -message $_ -Level EXCEPTION
                    Write-Host $_.Exception.Message -ForegroundColor Red
                }
            }
        }
        else
        {
            if ( -not $Name )
            {
                $Name = "Default"
            }
            $credential = Get-Credential -Message "Credential name '$($Name)' do not found. Type information."
            if ($credential)
            {
                if ($script:NotCredSave -notcontains $Name)
                {
                    $toSave = Read-Host -Prompt "`nWarn: Do you want to save this credential named $($Name)? (Y/N)"
                    if ($toSave -ieq 'Y')
                    {
                        $credential = New-WLCredential -UserName $credential.UserName -Password $credential.Password -Name $Name   
                    }
                    else
                    {
                        $script:NotCredSave += $Name
                    }
                }
                Write-Output $credential
            }
        }
    }
 
    #.ExternalHelp ../psWeblogic.Help.xml
    function Remove-WLCredential
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$True, Position = 1)]
            [Alias('Alias')]
                [string]$Name,
            [Parameter(Mandatory = $false)]
                [String]$Path = (Join-Path -Path $Script:appdata -ChildPath security)
        )
        BEGIN {}
        PROCESS
        {
            Get-ChildItem -Path $Path -Filter $Name | Remove-Item
        }
        END {}
    }

    #.ExternalHelp ../psWeblogic.Help.xml
    function Show-WLCredential
    {
       param([Parameter(Mandatory=$False,
                ValueFromPipeline=$True,
                HelpMessage="Use PSCredential object.")]
                    [System.Management.Automation.PSCredential]$Credential
            )
 
       # Just to see password in clear text
       $item = "" | select UserName,Password
       $item.UserName = $Credential.UserName
       $item.Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))
       Write-Output $item
    }

    Export-ModuleMember -Function New-WLCredential, Remove-WLCredential, New-WLCredential, Get-WLCredential
#endregion PSTip Storing of credentials