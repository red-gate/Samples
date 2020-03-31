# Script to import the contents of a .csv file into the metadata for a particular database in SQL Data Catalog

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$databaseName = "AdventureWorks"

$csvPath = "Classification_01.csv"

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# Get the data from the .csv file
$data = Import-Csv $csvPath |
    Select-Object Schema, Table, Column, "Information Type", "Sensitivity Label"

$columns = Get-ClassificationColumn -InstanceName $instanceName -DatabaseName $databaseName

for ($i = 0; $i -lt $data.Count; $i++) {
    if (-not $data[$i].Schema) {
        # Copy-down gaps in schema values, may not be needed in your scenario
        $data[$i].Schema = $data[$i - 1].Schema
    }
    $column = ($columns | Where-Object { $_.tableName -eq $data[$i].Table -and $_.columnName -eq $data[$i].Column})[0]

    $column | Add-ClassificationColumnTag -category 'Information Type' -tags @($data[$i].'Information Type')
    $column | Add-ClassificationColumnTag -category 'Sensitivity' -tags @($data[$i].'Sensitivity Label')
}
