$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$sourceDatabaseName = "AdventureWorks"
$destinationDatabaseName = "AdventureWorksCopy"

### This samples contains two variants
# 1) Copy classifications from one database to another within the same database instance
# 2) Copy classifications from one database instance to another

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

Copy-Classification -sourceInstanceName $instanceName -sourceDatabaseName $sourceDatabaseName `
    -destinationInstanceName $instanceName -destinationDatabaseName $destinationDatabaseName

<# Example 2 

# To copy from one database instance to another, simply set the -destinationInstanceName to the instance you'd
# like to copy to:

$DestinationInstanceName = 'sql-server2.domain.com' 

Copy-Classification `
    -sourceInstanceName $instanceName `
    -sourceDatabaseName $sourceDatabaseName `
    -destinationInstanceName $DestinationInstanceName `
    -destinationDatabaseName $destinationDatabaseName
#>



