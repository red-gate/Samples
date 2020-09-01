$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# local config
$instanceName = 'sql-server1.domain.com'
$databaseName = 'AdventureWorks'

$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName
$emailColumn = $allColumns |
    Where-Object { $_.ColumnName -like "EmailAddress" -and $_.SchemaName -like "Person" }
$emailColumn | Add-ClassificationColumnTag -category "Masking Data Set" -tags @("Email address")
$emailColumn | Add-ClassificationColumnTag -category "Information Classification" -tags @("Confidential")
$emailColumn | Add-ClassificationColumnTag -category "Treatment Intent" -tags @("Static Masking")
