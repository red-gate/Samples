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

$instances = Get-ClassificationInstance

$instanceId = @( $instances | Where-Object { $_.Name -eq $instanceName })[0].InstanceId
# Get the data from the .csv file
$data = Import-Csv $csvPath |
    Select-Object Schema, Table, Column, "Information Type", "Sensitivity Label"

for ($i = 0; $i -lt $data.Count; $i++) {
    if (-not $data[$i].Schema) {
        # Copy-down gaps in schema values, may not be needed in your scenario
        $data[$i].Schema = $data[$i - 1].Schema
    }
    $data[$i] | Add-Member -MemberType AliasProperty -Name SchemaName -Value Schema
    $data[$i] | Add-Member -MemberType AliasProperty -Name TableName -Value Table
    $data[$i] | Add-Member -MemberType AliasProperty -Name ColumnName -Value Column
    $data[$i] | Add-Member -MemberType NoteProperty -Name 'InstanceId' -Value $instanceId
    $data[$i] | Add-Member -MemberType NoteProperty -Name 'DatabaseName' -Value $databaseName
    $data[$i] | Add-ClassificationColumnTag -category 'Information Type' -tags @($data[$i].'Information Type')
    $data[$i] | Add-ClassificationColumnTag -category 'Sensitivity' -tags @($data[$i].'Sensitivity Label')
}
