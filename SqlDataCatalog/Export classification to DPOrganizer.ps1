# This sample was developed in cooperation with DPOrganizer (https://www.dporganizer.com/)
# This script exports three known tags that must exist in your taxonomy and aggregates these up to the database level:
# - Data Subject Category - The individuals whose data is stored in the catalog (e.g. Customers)
# - Person Responsible - The business entity who is responsible for this data (e.g. HR) 
# - Personal Data Types - The types of data that is stored (e.g. E-mail address, Phone number)
# If your taxonomy differs, this Cmdlet allows you to redefine what you would call Data Subject Category, e.g. "Subject"
[CmdletBinding()]
param (
    $ServerUrl = "http://[Your SQL Data Catalog Server FQDN]:15156", # or https:// if you've configured SSL
    $AuthToken = "[Your auth token]",
    $ExcludedDatabaseNames = @("SqlDataCatalog"),
    $dataSubjectCategory = "Data Subject Category",
    $personResponsible = "Person Responsible",
    $personalDataTypes = "Personal Data Types",
    $Path = ".\DPO.CSV"
)

Write-Host $ServerUrl
Invoke-WebRequest -Uri "$ServerUrl/powershell" -OutFile 'RedgateDataCatalog.psm1' -Headers @{"Authorization" = "Bearer $authToken" }
 
Import-Module .\RedgateDataCatalog.psm1
​
Connect-SqlDataCatalog -ServerUrl $ServerUrl -AuthToken $AuthToken
​
$databases = Get-ClassificationInstance | 
ForEach-Object { Get-ClassificationDatabase -InstanceName $_.Name } |
Where-Object { -not ($ExcludedDatabaseNames -contains $_.name) }
​
$tagCategories = Get-ClassificationTaxonomy | Select-Object -ExpandProperty "TagCategories"
$dataSubjectCategoryId = $tagCategories | Where-Object { $_.name -eq $dataSubjectCategory } | Select-Object -ExpandProperty "id"
$personResponsibleId = $tagCategories | Where-Object { $_.name -eq $personResponsible } | Select-Object -ExpandProperty "id"
$personalDataTypesId = $tagCategories | Where-Object { $_.name -eq $personalDataTypes } | Select-Object -ExpandProperty "id"

If (Test-Path $Path) {
    Remove-Item -Force -Path $Path
}
​
$databases | ForEach-Object {
    $database = $_
​
    $columns = Get-ClassificationColumn `
        -InstanceName $database.instanceName `
        -DatabaseName $database.name
    
    $columnTagsToExport = $columns | Where-Object { $_.tags.categoryId -eq $dataSubjectCategoryId }
    $export = ($columnTagsToExport | Select-Object  -Property  @{
            l = $dataSubjectCategory;
            e = {
                ($_.tags | 
                    Where-Object { $_.categoryId -eq $dataSubjectCategoryId } | 
                    Sort-Object "name" | 
                    Select-Object -ExpandProperty "name") -join "|"
            } 
        },
        @{
            l = $personResponsible;
            e = { $_.tags | Where-Object { $_.categoryId -eq $personResponsibleId } } 
        },
        @{
            l = $personalDataTypes;
            e = { $_.tags | Where-Object { $_.categoryId -eq $personalDataTypesId } } 
        }) |
    Group-Object $dataSubjectCategory | 
    Select-Object -Property @{
        l = 'Data Storage Name' # $dataStorageName
        e = { $database.instanceName.Replace('.', '_').Replace(',', '_') + '.' + $database.name }
    }, @{
        l = 'Data Storage Id' # $dataStorageId
        e = { $database.id }
    }, @{
        l = 'Data Subject Category' # $dataSubjectCategory;
        e = { $_.Name } 
    }, @{
        l = 'Person Responsible' # $personResponsible;
        e = { ($_.Group.$personResponsible.name | Select-Object -Unique | Sort-Object) -join "|" } 
    }, @{
        l = 'Personal Data Types' # $personalDataTypes;
        e = { ($_.Group.$personalDataTypes.name | Select-Object -Unique | Sort-Object) -join "|" } 
    }    

    $export | Export-Csv -Path $Path -NoTypeInformation -Append
} 