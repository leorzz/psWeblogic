#.ExternalHelp ../psWeblogic.Help.xml
function Set-WLEnvironment
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
    #[CmdletBinding()]

    param(
            [Parameter(Mandatory=$False)]
                [String]$DomainsInfoPath,
            [Parameter(Mandatory=$False)]
                [String]$DomainsInfoPathPublish,
            [Parameter(Mandatory=$False)]
                [String]$WLST,
            [Parameter(Mandatory=$False)]
            [ValidateSet($True,$False)]
                $CacheEnable,
            [Parameter(Mandatory=$False)]
                [Int]$TTLCacheSeconds,
            [Parameter(Mandatory=$False)]
            [ValidateSet($True,$False)]
                $DebugEnable
    )

    BEGIN
    {
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
    }# BEGIN

    PROCESS
    {
        try
        {
            $config = $Script:config.parameters.Environment

            if ($DomainsInfoPath)
            {
                $config | Add-Member -MemberType NoteProperty -Name DomainsInfoPath -Value $DomainsInfoPath -Force
                #$config.DomainsInfoPath = $DomainsInfoPath
            }
            if ($DomainsInfoPathPublish)
            {
                $config | Add-Member -MemberType NoteProperty -Name DomainsInfoPathPublish -Value $DomainsInfoPathPublish -Force
                #$config.DomainsInfoPathPublish = $DomainsInfoPathPublish
            }
            if ($WLST)
            {
                $config | Add-Member -MemberType NoteProperty -Name CacheEnable -Value $CacheEnable -Force
                $config.WLST = $WLST
            }
            if ($CacheEnable)
            {
                $config | Add-Member -MemberType NoteProperty -Name CacheEnable -Value ([System.Convert]::ToBoolean($CacheEnable)) -Force
                #$config.CacheEnable = [System.Convert]::ToBoolean($CacheEnable)
            }
            if ($TTLCacheSeconds)
            {
                $config | Add-Member -MemberType NoteProperty -Name TTLCacheSeconds -Value $TTLCacheSeconds -Force
                #$config.TTLCacheSeconds = $TTLCacheSeconds
            }
            if ($DebugEnable)
            {
                $config | Add-Member -MemberType NoteProperty -Name DebugEnable -Value ([System.Convert]::ToBoolean($DebugEnable)) -Force
                #$config.DebugEnable = [System.Convert]::ToBoolean($DebugEnable)
            }

            Copy-Item -LiteralPath $parametersPath -Destination "$($parametersPath).bak" -Force
            $orig = Get-Content -LiteralPath $parametersPath | ConvertFrom-Json
            $orig.parameters.Environment =  $config
            $orig | ConvertTo-Json | Out-File -LiteralPath $parametersPath -Encoding ascii -Force | Out-Null 
            Get-WLEnvironment
        }
        catch [Exception]
        {
            Write-Log -message $_.Exception.Message -Level Error
            Write-Host $_ -ForegroundColor Red
        }
    }# PROCESS

    END
    {

    }# END

}
Export-ModuleMember -Function Set-WLEnvironment
