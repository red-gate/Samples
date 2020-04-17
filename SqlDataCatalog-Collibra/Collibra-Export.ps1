$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$communityName = 'RedgateSqlDataCatalog'
$synchronizationId = 'RedgateSqlDataCatalog'
$collibraAPI = 'https://redgate.collibra.com/rest/2.0'
$collibraUserName = "[collibra user name here]"
$collibraPassword = "[collibra user password]"

. ".\convert-to-collibra.ps1"
. ".\collibra-api.ps1"

function export-database(
    [Parameter(Mandatory)][string] $instanceName,
    [Parameter(Mandatory)][string] $databaseName
) {
    # get all columns into a collection
    $allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName

    if (-not $allColumns) {
        throw "No columns returned, check if the instance '$instanceName' is" +
        "registered and that it contains a database '$databaseName'."
    }

    $exportJson = Convert-CollibraJSON -communityName $communityName -instanceName  $instanceName -databaseName $databaseName -columns $allColumns

    Import-BatchCollibraDatabase -synchronizationId $synchronizationId -json $exportJson
}

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile './data-catalog.psm1' -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl
Connect-Collibra -collibraAPI $collibraAPI -userName $collibraUserName  -password $collibraPassword

Get-ClassificationInstance
| ForEach-Object { Get-ClassificationDatabase -InstanceName $_.Name }
| ForEach-Object { export-database -instanceName $_.instanceName -databaseName $_.name }

Complete-CollibraSync -synchronizationId $synchronizationId
Disconnect-Collibra
