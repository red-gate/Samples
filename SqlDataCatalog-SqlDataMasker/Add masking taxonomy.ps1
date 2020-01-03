$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL


Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

Import-Module .\DataMaskerHelpers.psm1 -Force

# Set up the new tag category
$payload = @{
    name          = 'Masking Data Set'
    description   = "Used to mark columns for inclusion in SQL Data Masker masking scripts."
    isMultiValued = $False
}

$headers = @{"Authorization" = "Bearer $authToken" }


# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

$taxonomy = Get-ClassificationTaxonomy

if ('Masking Data Set' -notin $taxonomy.TagCategories.name) {
    $result = Invoke-WebRequest "$serverUrl/api/v1.0/taxonomy/tag-categories" -UseBasicParsing -Method Post `
        -Body (ConvertTo-Json $payload) -ContentType 'application/json' -Headers $headers

    if (-not $result.StatusDescription -eq "Created") {
        Write-Host "Unable to add Masking Data Set tag category"
        Exit
    }
    $addedCategoryGetUrl = $result.Headers.Location
}
else {
    $maskingDataSetTagCategoryId = $taxonomy.TagCategories |
        Where-Object { $_.name -eq 'Masking Data Set' } |
        Select-Object -ExpandProperty id
    $addedCategoryGetUrl = "$serverUrl/api/v1.0/taxonomy/tag-categories/$maskingDataSetTagCategoryId"
}

$maskingDataSetTags = $taxonomy.TagCategories |
    Where-Object { $_.name -eq 'Masking Data Set' } |
    Select-Object -ExpandProperty tags |
    Select-Object -ExpandProperty name

foreach ($tagname in Get-MaskingTaxonomyTags) {

    if ($tagname -in $maskingDataSetTags) {
        continue
    }

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
