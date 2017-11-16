function Test-Url
{
    Param(
            [String]$url,
            [System.Net.NetworkCredential]$Credentials=$null,
            [int]$Timeout=60
          )
    try
    {
        $req = [system.Net.WebRequest]::Create($url)
        $req.Timeout = $Timeout * 1000
        
        if ($Credentials)
        {
            $req.AuthenticationLevel =  [System.Net.Security.AuthenticationLevel]::MutualAuthRequested
            $req.credentials = $Credentials
        }
        else
        {
            $req.UseDefaultCredentials = $true   
        }
    }
    catch
    {
        #Write-Host $_ -ForegroundColor Red
        return $null
    }
    try 
    {
            $res = $req.GetResponse()
    } 
    catch [System.Net.WebException] 
    {
            $res = $_.Exception.Response
    }

    if ($res)
    {
        [int]$codeValue = $res.StatusCode
        Add-Member -InputObject $res -NotePropertyName StatusCodeInt -NotePropertyValue $codeValue
        return $res
    }
    else
    {
        return $null
    }
    
}

