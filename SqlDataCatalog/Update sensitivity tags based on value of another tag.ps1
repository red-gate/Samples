# Script to bulk update the sensitivity tags for a database which match a given condition; in this case that there is a tag marked 'Out of scope - Non PII'

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$databaseName = "AdventureWorks"


Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverURL

# get all columns into a collection
$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName

$outOfScopeColumns = $allColumns |
    Where-Object { $_.tags.Name -eq "Out of scope - Non PII" }

$outOfScopeColumns |
    Add-ClassificationColumnTag -category "Sensitivity" -tags @("Non PII")
