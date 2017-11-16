# Busca por uma string no conteï¿½do de arquivos. Analogo ao grep.
function Find-Str 
{
    Param(
            [String]$SubString,
            [String]$Path = ".",
            [String]$Include = "*",
            [Switch]$Recurse = $false
    )

    Start-Sleep -Seconds 1
    Get-ChildItem $Path -File -Recurse:$Recurse -Include $Include | % {
    
        $item = "" | select "fullFileName","Count","Line"
        $item.fullFileName = $_.FullName
        $i = 1
        $lines_match = New-Object -TypeName "System.Text.StringBuilder"; 
        $line = @()
        Get-Content $_ | % {
                    if ($_ -match $SubString)
                    {
                        $lines_match.AppendLine("{0:0000}" -f $i + ": " + $($_)) | Out-Null
                        $item.Count += 1
                        #Write-Host $fileName
                        #Write-Host "`tl:$($i)  " $_

                    }
                    $i++
                  }
                  $item.Line = $lines_match.ToString()
              
              
                  if ($item.Line -ne "")
                  {
                       $item
                       
                  }
   
   }

}