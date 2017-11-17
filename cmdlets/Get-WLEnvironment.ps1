#.ExternalHelp ../psWeblogic.Help.xml
function Get-WLEnvironment
{
    # http://technet.microsoft.com/en-us/library/hh847872.aspx
     [CmdletBinding()]

    param()

    BEGIN
    {
        $IsLastPipe = $MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition
    }# BEGIN

    PROCESS
    {
        try
        {
            Write-Host "Config file: $($parametersPath)" -ForegroundColor Green
            Write-Output $Script:config.parameters.environment
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
Export-ModuleMember -Function Get-WLEnvironment
