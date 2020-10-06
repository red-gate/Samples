# Based on the structure of AdventureWorks (see `Classify Adventureworks database`)
# Presumes that you have the foundational information types and information classification tags

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

LoadSqlDataCatalogPowerShellModule

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# Descope ID-based columns across our estate
$idColumns = Get-ClassificationColumn -ColumnNameFilterString "id" -ColumnDataTypeFullNames @("bigint", "int")

$idCategories = @{
    "Information Classification" = @("System")
    "Classification Scope" = @("Out of scope - System")
}

Set-Classification -columns $idColumns -categories $idCategories

# create group of columns for email
$emailColumns = Get-ClassificationColumn -ColumnNameFilterString "email"

# exclude any columns that might contain "id" (e.g. "email_id")
$emailColumns = $emailColumns | Where-Object { $_.ColumnName -notlike "*id*" }

if (-not $emailColumns) {
    throw "No e-mail columns returned in any of your registered databases across your estate."
}

# Classify the columns
$emailCategories = @{
    "Information Type" = @("Email address")
    "Information Classification" = @("Confidential")
    "Classification Scope" = @("In-scope")
}

Set-Classification -columns $emailColumns -categories $emailcategories

function LoadSqlDataCatalogPowerShellModule() {
    Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

    Import-Module .\data-catalog.psm1 -Force
}