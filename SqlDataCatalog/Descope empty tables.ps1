$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$databaseName = 'AdventureWorks'
$scopeCategory = "Classification Scope"
$unusedTag = "Out of Scope - Unused"

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# get all columns into a collection
$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName

"Columns returned: " + $allColumns.Count

$emptyTableColumns = $allColumns | Where-Object { $_.tableRowCount -eq 0 }
$emptyTableColumnsInDboSchema = $emptyTableColumns | Where-Object { $_.schemaName -eq 'dbo' }

# Add-ClassificationColumnTag does a non-destructive update on all these columns (i.e. other tags are not removed)
$emptyTableColumnsInDboSchema | Add-ClassificationColumnTag -category "Sensitivity" -tags "General"
$emptyTableColumnsInDboSchema | Add-ClassificationColumnTag -category $scopeCategory -tags $unusedTag
