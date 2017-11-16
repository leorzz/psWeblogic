function Import-Excel
{
    param (
    [string]$FileName,
    [string]$WorksheetName
    )

    BEGIN
    {
        if ($FileName -eq "") {
            throw "Please provide path to the Excel file"
            break
        }

        if (-not (Test-Path $FileName)) {
            throw "Path '$FileName' does not exist."
            break
        }
    }

    PROCESS
    {
        $strSheetName = $WorksheetName + '$'
        $query = 'select * from ['+$strSheetName+']';

        $connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source='$($FileName)';Extended Properties='Excel 12.0 Xml;HDR=YES';"
        $conn = New-Object System.Data.OleDb.OleDbConnection($connectionString)
        $conn.open()

        $cmd = New-Object System.Data.OleDb.OleDbCommand($query,$conn) 
        $dataAdapter = New-Object System.Data.OleDb.OleDbDataAdapter($cmd) 
        $dataTable = New-Object System.Data.DataTable 

        $dataAdapter.fill($dataTable) | Out-Null
        $conn.close()

        $myDataRow ="";
        $columnArray =@();
        foreach($col in $dataTable.Columns)
        {
            $columnArray += $col.toString();
        }

        $returnObject = @();
        foreach($rows in $dataTable.Rows)
        {
            $i=0;
            $rowObject = @{};
            foreach($columns in $rows.ItemArray){
                $rowObject += @{$columnArray[$i]=$columns.toString()};
                $i++;
            } 

            $returnObject += new-object PSObject -Property $rowObject;
        }

        return $returnObject;
    }

    END
    {}
} 
