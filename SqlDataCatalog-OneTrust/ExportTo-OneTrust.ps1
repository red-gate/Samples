# This sample was developed in cooperation with OneTrust (https://www.onetrust.com/)
# This script exports two known tags that must exist in your taxonomy and aggregates these up to the database level:
# - Data Subject - The individuals whose data is stored in the catalog (e.g. Customers)
# - Data Elements - The types of data that is stored (e.g. E-mail address, Phone number)
# If your taxonomy differs, this Cmdlet allows you to redefine what you would call Data Subject, e.g. "Subject"
# Please note that 
# - the Subject names must match those registered in OneTrust (Data Mapping - Setup - Inventory Manager - Data Subject Types - Key)
# - the Element names must match those registed in OneTrust (Data Mapping - Setup - Inventory Manager - Data Elements - Key)
# - there must be a registed Asset type called "Instance" in OneTrust (Data Mapping - Setup - Inventory Manager - Asset Attributes - Type) 
[CmdletBinding()]
param (
    $ServerUrl = "http://[Your SQL Data Catalog Server FQDN]:15156", # or https:// if you've configured SSL
    $AuthToken = "[Your auth token]",
    $ExcludedDatabaseNames = @("SqlDataCatalog"),
    $DataSubject = "Data Subject",
    $DataElements = "Data Elements",
    $UseCachedModule = $false,
    $OneTrustHostName = '[Your OneTrust host name here]',
    $OneTrustApiKey = '[Your OneTrust API Key here]',
    $AssetOrganization = 'Redgate',
    $AssetLocation = 'United States'
)

#region OneTrust Integration
$script:upsertAssetBaseUri = "https://$OneTrustHostName/api/inventory/v2/inventories/assets/reference/"
$createdInstances = @{}
$DATA_SUBJECT = 'Data Subject'
$DATA_ELEMENT = 'Data Element'
$instanceDatabaseAssociations = @{}
function script:associate($databaseId, $withInstanceId) {
    If (-not $instanceDatabaseAssociations.ContainsKey($withInstanceId)) {
        $instanceDatabaseAssociations.Add($withInstanceId, [System.Collections.ArrayList]@())
    }
    $instanceDatabaseAssociations[$withInstanceId].Add($databaseId)
}
function script:linkAssets() {
    $headers = @{
        'content-type' = 'application/json'
        'apikey' = $OneTrustApiKey
    }
    foreach ($sourceAssetId in $instanceDatabaseAssociations.Keys) {
        $body = @($instanceDatabaseAssociations[$sourceAssetId] |
            Select-Object -Property @{ l='id'; e={$_} },@{ l='relation'; e={ 'RelatedLinkType' } }) |
            ConvertTo-Json
        return Invoke-WebRequest `
            -Uri "https://$OneTrustHostName/api/inventory/v2/inventories/$sourceAssetId/relations" `
            -Method POST `
            -Headers $headers `
            -ContentType 'application/json' `
            -Body $body
    }
}
function script:upsertAsset($id, $name, $type) {
    $upsertAssetUri = $script:upsertAssetBaseUri + $id
    $headers = @{
        'content-type' = 'application/json'
        'apikey' = $OneTrustApiKey
    }
    $body = @{
        'name' = $name
        'organization' = @{ 'value' = $AssetOrganization }
        'location' = @{ 'value' = $AssetLocation }
        'type' = @(@{ 'value' = $type })
    } | ConvertTo-Json
    $response = Invoke-WebRequest -Uri $upsertAssetUri -Method PUT -Headers $headers `
        -ContentType 'application/json' -Body $body
    return ($response.Content | ConvertFrom-Json).data.id  
}
function script:upsertAssets($instanceId, $instanceName, $databaseId, $databaseName, $tags) {

    If (-not ($createdInstances.ContaInsKey($instanceId))) {
        $assetId = script:upsertAsset -id $instanceId -name $instanceName -type 'Instance'
        $createdInstances.Add($instanceId, $assetId)
    }
    $instanceAssetId = $createdInstances[$instanceId]

    $databaseAssetId = script:upsertAsset `
        -id $databaseId `
        -name $databaseName `
        -type 'Database'

    script:associate -databaseId $databaseAssetId -withInstanceId $instanceAssetId
    
    foreach ($dataset in $tags) {
        $dataSubjects = $dataset.$DATA_SUBJECT
        $dataElements = $dataset.$DATA_ELEMENT

        $ObjectArray = [System.Collections.ArrayList]@()
        foreach ($dataSubject in $dataSubjects.Split('|')) {
            foreach ($dataElement in $dataElements.Split('|')) {
        
                "$dataSubject = $dataElement"
                $ObjectArray.Add(@{$dataSubject = $dataElement})
            }
        }
        $ObjectArray
    }
}
#endregion

Write-Host $ServerUrl

#region Load Redgate Data Catalog Module
$moduleName = 'RedgateDataCatalog.psm1'
If (-not $UseCachedModule -or -not (Test-Path $moduleName)) {
    Invoke-WebRequest -Uri "$ServerUrl/powershell" -OutFile $moduleName `
        -Headers @{ 'Authorization' = "Bearer $AuthToken" }
}
Import-Module ".\$ModuleName"
#endregion

Connect-SqlDataCatalog -ServerUrl $ServerUrl -AuthToken $AuthToken

$databases = Get-ClassificationInstance | 
    ForEach-Object { Get-ClassificationDatabase -InstanceName $_.Name } |
    Where-Object { -not ($ExcludedDatabaseNames -contains $_.name) }
    
$tagCategories = Get-ClassificationTaxonomy | Select-Object -ExpandProperty "TagCategories"
$DataSubjectId = $tagCategories | Where-Object { $_.name -eq $DataSubject } | Select-Object -ExpandProperty "id"
$DataElementsId = $tagCategories | Where-Object { $_.name -eq $DataElements } | Select-Object -ExpandProperty "id"

$databases | ForEach-Object {
    $database = $_

    $columns = Get-ClassificationColumn `
        -InstanceName $database.instanceName `
        -DatabaseName $database.name

    $columnTagsToExport = $columns | Where-Object { $_.tags.categoryId -eq $DataSubjectId }
    $export = ($columnTagsToExport | Select-Object  -Property  @{
            l = $DataSubject;
            e = {
                ($_.tags | 
                    Where-Object { $_.categoryId -eq $DataSubjectId } | 
                    Sort-Object "name" | 
                    Select-Object -ExpandProperty "name") -join "|"
            } 
        },
        @{
            l = $DataElements;
            e = { $_.tags | Where-Object { $_.categoryId -eq $DataElementsId } } 
        }) |
    Group-Object $DataSubject | 
    Select-Object -Property @{
        l = $DATA_SUBJECT
        e = { $_.Name } 
    }, @{
        l = $DATA_ELEMENT
        e = { ($_.Group.$DataElements.name | Select-Object -Unique | Sort-Object) -join "|" } 
    }

    script:upsertAssets `
        -instanceId $database.instanceId `
        -instanceName $database.instanceName.Replace('.', '_').Replace(',', '_') `
        -databaseId $database.id `
        -databaseName $database.name.Replace('.', '_').Replace(',', '_') `
        -tags $export
}

script:linkAssets
