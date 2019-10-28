# Script to import the contents of a .csv file into the metadata for a particular database in SQL Data Catalog

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$databaseName = "AdventureWorks"

$csvPath = "Classification_01.csv"

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

$instances = Get-ClassificationInstance

$instanceId = @( $instances | Where-Object { $_.Name -eq $instanceName })[0].InstanceId
# Get the data from the .csv file
$importedData = Import-Csv $csvPath |
    Select-Object Schema, Table, Column, "Information Type", "Sensitivity Label"

for ($i = 0; $i -lt $importedData.Count; $i++) {
    if (-not $importedData[$i].Schema) {
        # Copy-down gaps in schema values, may not be needed in your scenario
        $importedData[$i].Schema = $importedData[$i - 1].Schema
    }
    $importedData[$i] | Add-Member -MemberType AliasProperty -Name SchemaName -Value Schema
    $importedData[$i] | Add-Member -MemberType AliasProperty -Name TableName -Value Table
    $importedData[$i] | Add-Member -MemberType AliasProperty -Name ColumnName -Value Column
    $importedData[$i] | Add-Member -MemberType NoteProperty -Name 'InstanceId' -Value $instanceId
    $importedData[$i] | Add-Member -MemberType NoteProperty -Name 'DatabaseName' -Value $databaseName
    $importedData[$i] | Add-ClassificationColumnTag -category 'Information Type' -tags @($importedData[$i].'Information Type')
    $importedData[$i] | Add-ClassificationColumnTag -category 'Sensitivity' -tags @($importedData[$i].'Sensitivity Label')
}
