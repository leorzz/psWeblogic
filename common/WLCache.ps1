#region WLResourceCache
    # Create new cache resource in temp file
    #.ExternalHelp ../psWeblogic.Help.xml
    function New-WLResourceCache
    {
        [CmdletBinding()]
        Param($Uri,$UserName,$ResourceObject)

        try
        {
            if ($Script:config.parameters.environment.CacheEnable)
            {
                $checksum = (Get-Md5CheckSum $Uri) -replace '-',''
                $Content = "" | select Checksum,Uri,Content
                $Content.Checksum = $checksum
                $Content.Uri = $Uri
                $Content.Content = $ResourceObject
                $item = New-Item -Path $env:TEMP -Name "wl_$($checksum).tmp" -Force -Value ($Content | ConvertTo-Json -Depth 100 -Compress) -ItemType file
    
                $cacheItem = "" | Select Uri,ValidTo,FullName,UserName,Checksum
                $cacheItem.Uri = $Uri
                $cacheItem.FullName = $item.FullName
                $cacheItem.UserName = $UserName
                $cacheItem.Checksum = $checksum

                try
                {
                    $cacheItem.ValidTo = (Get-Date).AddSeconds([int]$Script:config.parameters.environment.TTLCacheSeconds)
                }
                catch [Exception]
                {
                    $cacheItem.ValidTo = (Get-Date).AddSeconds(120)
                }

                $itemExist = $Script:ResourceCacheIndex | ? {$_.Checksum -eq $checksum}
                if ($itemExist)
                {
                    $itemExist.ValidTo = $cacheItem.ValidTo
                }
                else
                {
                    $null = $Script:ResourceCacheIndex.Add($cacheItem)
                }
                Write-Debug "New query: $($cacheItem.Uri)"
            }
            else
            {
                return $null
            }
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            return $null
        }
    }

    #.ExternalHelp ../psWeblogic.Help.xml
    function Get-WLResourceCache
    {
        [CmdletBinding()]
        Param([String]$Uri,[String]$UserName,[Switch]$Force)

        try
        {
            if ($Script:config.parameters.environment.CacheEnable)
            {
                $item = $Script:ResourceCacheIndex | ? {$_.Checksum -eq $((Get-Md5CheckSum $Uri) -replace '-','')}
                if ($item)
                {
                    $result = (Get-Content -LiteralPath $item.FullName | ConvertFrom-Json).Content
                    if ($Force.IsPresent)
                    {
                        if ($result)
                        {
                            #Write-Host "Force Cache: $($item.FullName)" -ForegroundColor Cyan
                            Write-Debug "Force Cache: $($item.FullName)"
                            Write-Debug "Uri: $($Uri)"
                            Write-Debug "ValidTo: $($Item.ValidTo)"
                            return $result
                        }
                        else
                        {
                            Write-Debug "Missing cache: $($Uri)"
                            return $null
                        }
                    }
                    elseif ( ($Item.ValidTo -and (($Item.ValidTo - (Get-Date)).TotalSeconds -gt 0)) )
                    {
                        if ($result)
                        {
                            #Write-Host "Cache: $($item.FullName)" -ForegroundColor Cyan
                            Write-Debug "Force Cache: $($item.FullName)"
                            Write-Debug "Uri: $($Uri)"
                            Write-Debug "ValidTo: $($Item.ValidTo)"
                            return $result
                        }
                        else
                        {
                            Write-Host "No valid cache: $($Uri) before $($Item.ValidTo)." -ForegroundColor Cyan
                            return $null
                        }
                    }
                    else
                    {
                        Write-Debug "Missing cache: $($Uri)"
                        return $null
                    }
                }
                else
                {
                    return $null
                }
            }
            else
            {
                return $null
            }
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            return $null
        } 
    }

    #.ExternalHelp ../psWeblogic.Help.xml
    function Remove-WLResourceCache
    {
        Param($UriMatch)
        try
        {
            $Script:ResourceCacheIndex | ? { $_.Uri -match $UriMatch } | foreach {
                                                                                    $_.ValidTo = $null; 
                                                                                    Write-Debug "Removed CacheIndex: $($_.Uri)";
                                                                                }
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            return $null
        }
    }

    #.ExternalHelp ../psWeblogic.Help.xml
    function Get-WLCacheIndex
    {
        try
        {
            if ($Script:config.parameters.environment.CacheEnable)
            {
                Return $Script:ResourceCacheIndex
            }
            else
            {
                return $null
            }
        }
        catch [Exception]
        {
            Write-Log -message $_ -Level EXCEPTION
            return $null
        } 
    }

    #.ExternalHelp ../psWeblogic.Help.xml
    function Repair-WLCacheIndex
    {
        Write-Host "Repair cache index..." -ForegroundColor Cyan
        $files = Get-ChildItem -Path $env:TEMP -Filter wl_*.tmp
        $Script:ResourceCacheIndex = New-Object System.Collections.ArrayList
        $files | % { 
                        try
                        {
                            if($Script:config.parameters.environment.TTLCacheSeconds -is [int])
                            {
                                $validTo = ($_.LastWriteTime).AddSeconds([int]$Script:config.parameters.environment.TTLCacheSeconds) 
                            }
                            else
                            {
                                $validTo = (Get-Date).AddSeconds(600)
                            }

                            $content = Get-Content $_.FullName | ConvertFrom-Json 
                            if ((Get-Date) -le $validTo)
                            {
                                $cacheItem = "" | Select Uri,ValidTo,FullName,UserName,Checksum
                                $cacheItem.Uri = $content.Uri
                                $cacheItem.FullName = $_.FullName
                                $cacheItem.Checksum = $content.Checksum
                                $cacheItem.ValidTo = $validTo
                                if ($Script:ResourceCacheIndex.Checksum -notcontains $cacheItem.Checksum)
                                {
                                    $null = $Script:ResourceCacheIndex.Add($cacheItem)
                                }
                                #Write-Debug "Repair index: $($cacheItem.Uri)"
                            }
                            else
                            {
                                #Write-Debug "Repair index: Nothing"
                            }
                        }
                        catch [Exception]
                        {
                            Write-Log -message $_ -Level EXCEPTION
                            Write-Debug $_.Exception.Message
                        }
                 }
    }
    Export-ModuleMember -Function Get-WLCacheIndex, Repair-WLCacheIndex
#endregion WLResourceCache
