$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

Import-Module .\DataMaskerHelpers.psm1 -Force

# Set up the new tag category
$payload = @{
    name          = 'Masking Data Set'
    description   = "Used to mark columns for inclusion in SQL Data Masker masking scripts."
    isMultiValued = $False
}

$headers = @{"Authorization" = "Bearer $authToken" }

$result = Invoke-WebRequest $serverUrl/api/v1.0/tagcategories -UseBasicParsing -Method Post `
    -Body (ConvertTo-Json $payload) -ContentType 'application/json' -Headers $headers

if (-not $result.StatusDescription -eq "Created") {
    Write-Host "Unable to add Masking Data Set tag category"
    Exit
}

$addedCategoryGetUrl = $result.Headers.Location

foreach ($tagname in Get-MaskingTaxonomyTags) {
    $tag = @{
        name        = $tagname
        description = $tagname
    }

    $result = Invoke-WebRequest $addedCategoryGetUrl/tags -UseBasicParsing -Method Post `
        -Body (ConvertTo-Json $tag) -ContentType 'application/json' -Headers $headers

    if (-not $result.StatusDescription -eq "Created") {
        Write-Host "Unable to add Masking Data Set tag"
        Exit
    }
}
