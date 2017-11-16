Import-Module -Name TabExpansionPlusPlus -Global -ea SilentlyContinue

$cmdAdminServer = Get-Command -Module $Script:mInfo.Name -ParameterName AdminServer -Verb get,new,start,stop,restart,remove | Where-Object {$_.Name -ne "New-WLDomain"}
$cmdCredential = Get-Command -Module $Script:mInfo.Name -ParameterName Credential

#if (Get-Command Register-ArgumentCompleter -Module TabExpansionPlusPlus -ea Ignore)
if (Get-Module -Name TabExpansionPlusPlus)
{
    # http://www.powertheshell.com/dynamicargumentcompletion/
    # https://github.com/lzybkr/TabExpansionPlusPlus
    $cmdAdminServer | ForEach-Object {
            Register-ArgumentCompleter -CommandName $_.Name -ParameterName "AdminServer" -ScriptBlock {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                foreach($completionTarget in (Get-WLDomain))
                {
                    New-CompletionResult -CompletionText $($completionTarget.AdminServer) -ListItemText $($completionTarget.AdminServer) -ToolTip $($completionTarget.Version.Tostring())
                }
            } -Description "This argument completer handles the -AdminServer parameter of all psWeblogic CMDLETS"

    }#cmdAdminServer

    $cmdCredential | ForEach-Object {
            Register-ArgumentCompleter -CommandName $_.Name -ParameterName "Credential" -ScriptBlock {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
                $path = Get-WLCredential
                if ($path)
                {
                    $path | ForEach-Object { New-CompletionResult -CompletionText ("(Get-WLCredential -Name $($_.Name))") -ListItemText $_.Name -NoQuotes }
                }
            } -Description "This argument completer handles the -Credential parameter of all $($Script:mInfo.Name) CMDLETS"
    }#cmdAdminServer


    Register-ArgumentCompleter -CommandName Get-WLDomain -ParameterName "Name" -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        Get-WLDomain | ForEach-Object { New-CompletionResult -CompletionText $($_.Name) -ListItemText $($_.Name) -ToolTip $($_.Version.Tostring()) }
    } 
    Register-ArgumentCompleter -CommandName Get-WLDomain -ParameterName "Version" -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        Get-WLDomain | Select -Property Version -Unique | ForEach-Object { New-CompletionResult -CompletionText $($_.Version) -ListItemText $($_.Version) }
    } 
}
elseif (Get-Command Register-ArgumentCompleter -Module Microsoft.PowerShell.Core -ea Ignore)
{
    #https://technet.microsoft.com/en-us/library/mt631420.aspx
    $cmdAdminServer | ForEach-Object {
            Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName $_.Name -ParameterName "AdminServer" -ScriptBlock { Get-WLDomain | Sort-Object -Property AdminServer | ForEach-Object {$_.AdminServer} }
        }#Commands

    $cmdCredential | ForEach-Object {
            Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName $_ -ParameterName "Credential" -ScriptBlock { Get-WLCredential | ForEach-Object {"(Get-WLCredential -Name $($_.Name))"} }
    }
    Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName Get-WLDomain -ParameterName "Name" -ScriptBlock { Get-WLDomain | Sort-Object -Property Name | ForEach-Object {$_.Name} }
    Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName Get-WLDomain -ParameterName "Version" -ScriptBlock { Get-WLDomain | Select -ExpandProperty Version -Unique | ForEach-Object {$_.toString()} }
}
