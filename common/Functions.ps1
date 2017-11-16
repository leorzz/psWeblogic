# http://stackoverflow.com/questions/10521061/how-to-get-an-md5-checksum-in-powershell
# https://msdn.microsoft.com/pt-br/library/system.text.encoding(v=vs.110).aspx
function Get-Md5CheckSum
{
    Param(
        [Parameter(Mandatory=$False, Position = 1)]
        [String]$Text
       )
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $encoding = new-object -TypeName System.Text.UTF8Encoding
    $encoding = new-object -TypeName System.Text.ASCIIEncoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($encoding.GetBytes($Text)))
    return $hash
}


 #Convert a text from the DOS format to the UNIX format.
#The format is different in the last character of each line. 
#The DOS format ends with a carriage return (Cr) line feed (Lf) 
#character whereas the UNIX format uses the line feed (Lf) character.
function ConvertTo-Unix
{
    begin
    {}
    process
    {
        ($_ | Out-String) -replace "`r`n","`n"
    }
    end
    {}
}

#Convert a text from the UNIX format to the DOS format.
#The format is different in the last character of each line. 
#The DOS format ends with a carriage return (Cr) line feed (Lf) 
#character whereas the UNIX format uses the line feed (Lf) character.
function ConvertFrom-Unix
{
    begin
    {}
    process
    {
        ($_ | Out-String) -replace "`n","`r`n"
    }
    end
    {}
}

# Taking a secure password and converting to plain text
Function ConvertTo-PlainText( [security.securestring]$secure ) {
    $marshal = [Runtime.InteropServices.Marshal]
    $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($secure) )
}



# Test is the text is JSON format
function Test-Json
{
    Param([String]$Text,[int]$RecursionLimit=99)
    try
    {
        # https://msdn.microsoft.com/en-us/library/system.web.script.serialization.javascriptserializer%28v=vs.110%29.aspx
        $jsser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $jsser.MaxJsonLength = $jsser.MaxJsonLength * 10
        $jsser.RecursionLimit = $RecursionLimit
        $outObject = $jsser.DeserializeObject($json)
        $jsser, $outObject = $null
        return $true
    }
    catch [Exception]
    {
        Write-Log -message $_ -Level EXCEPTION
        return $false
    }

}


function Set-StandardMembers
{
    # http://stackoverflow.com/questions/1369542/can-you-set-an-objects-defaultdisplaypropertyset-in-a-powershell-v2-script/1891215#1891215
    Param([PSObject]$MyObject,[String[]]$DefaultProperties)
        try
        {
            $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$DefaultProperties)
            $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
            $MyObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers -Force
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            Write-Debug $_.Exception.Message
        }
}




function Get-EpochDate 
{ 
    Param($epochdate) 
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliseconds($epochdate)) 
}

