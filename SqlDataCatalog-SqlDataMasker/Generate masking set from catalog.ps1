# Modify $authToken, $serverUrl, $productionInstanceName, $productionDatabaseName to match your config.

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

# The instance and database that have been classified in Data Catalog.
$productionInstanceName = 'sql-server1.domain.com'
$productionDatabaseName = 'AdventureWorks'

$maskingSetPath = "AdventureWorks.DMSMaskSet"

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

Import-Module .\DataMaskerHelpers.psm1 -Force

Test-DataMaskerExists

$mappingFilePath = "./ColumnTemplateMapping.json"

$logsDirectoryPath = "$PWD/Logs"
if (-Not (Test-Path $logsDirectoryPath)) {
    New-Item -ItemType Directory -Path $logsDirectoryPath
}

# This builds a JSON file mapping each column to a Data Masker column template.
Import-ColumnTemplateMapping `
    -CatalogUrl $serverUrl `
    -CatalogAuthToken $authToken `
    -SqlServerHostName $productionInstanceName `
    -DatabaseName $productionDatabaseName `
    -InformationTypeCategory "Information Type" `
    -SensitivityCategory "Treatment Intent" `
    -SensitivityTag "Static Masking" `
    -MappingFilePath $mappingFilePath `
    -LogDirectory $logsDirectoryPath

# You can edit the column template mappings JSON file here,
# to customise how you would like to mask your columns.

# This builds a masking set based on the JSON file.
# There is an alternative cmdlet: ConvertTo-MaskingSetUsingSqlAuth.
ConvertTo-MaskingSetUsingWindowsAuth `
    -OutputMaskingSetFilePath $maskingSetPath `
    -LogDirectory $logsDirectoryPath `
    -SqlServerHostName $productionInstanceName `
    -DatabaseName $productionDatabaseName `
    -InputMappingFilePath $mappingFilePath

# The masking set can now be run against a non-production database using Invoke-MaskDatabase.

Write-Output "Masking set generated as $PSScriptRoot\$maskingSetPath"
Get-ChildItem $PSScriptRoot\$maskingSetPath | Write-Output
