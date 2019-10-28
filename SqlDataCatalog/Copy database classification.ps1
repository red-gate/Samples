$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$sourceDatabaseName = "AdventureWorks"
$destinationDatabaseName = "AdventureWorksCopy"


Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

Copy-Classification -sourceInstanceName $instanceName -sourceDatabaseName $sourceDatabaseName `
    -destinationInstanceName $instanceName -destinationDatabaseName $destinationDatabaseName
