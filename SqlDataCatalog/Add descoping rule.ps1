# Based on the structure of AdventureWorks (see `Classify Adventureworks database`)
# Presumes that you have the foundational information types and information classification tags

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

# Load SQL Data Catalog PowerShell Module
Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
-Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

$body = @{
    name     = "ZZ. Descope system columns"
    tagIds   = @(491288012315960037, 491288012315962001)
    filters = @(
        {
            primaryKeyFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            foreignKeyFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            compositeKeyFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            identityConstraintFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("bit", "uniqueidentifier")
        }
    )
}

Invoke-WebRequest -Uri "$serverUrl/api/v1.0/suggestion-rules" -Method Post -Body $body
