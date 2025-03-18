$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

# Load SQL Data Catalog PowerShell Module
Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
-Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# Connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# Create new filter object
$filter = New-ClassificationColumnFilter

# Add exclusion filter for all columns ending with ID or which have uniqueidentifier type
$filter.columns.excludePartial = @("%id")
$filter.columnDataTypes.exclude = @("uniqueidentifier")

# Get the first 25 results matching the filter
Get-ClassificationColumnForFilter $filter -MaxNumberOfResults 25