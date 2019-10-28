$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$databaseName = 'AdventureWorks'

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# get all columns into a collection
$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName

if (-not $allColumns) {
    throw "No columns returned, check if the instance '$instanceName' is" +
    "registered and that it contains a database '$databaseName'."
}

# create group of columns for email
$emailColumns = $allColumns |
    Where-Object { $_.ColumnName -like "*email*" } |
    Where-Object { $_.ColumnName -notlike "*id*" }

$emailCategories = @{
    "Sensitivity"      = @("Confidential - GDPR")
    "Information Type" = @("Contact Info")
}
Set-Classification -columns $emailColumns -categories $emailcategories


# create group of columns for id columns
$idColumns = $allColumns | Where-Object { $_.ColumnName -like "*id" }

$idCategories = @{
    # please make sure that your taxonomy has the 'System' tag added to the 'Sensitivity' category
    "Sensitivity"      = @("System")
    "Information Type" = @("Other")
}

Set-Classification -columns $idColumns -categories $idCategories

# create group of columns for non-sensitive geographic fields
$geoColumns = $allColumns | Where-Object { $_.tableName -like "*Country*" }

$geoCategories = @{
    "Sensitivity"      = @("General")
    "Information Type" = @("Other")
}

Set-Classification -columns $geoColumns -categories $geoCategories

# create group of columns for system-internal tables and columns
$systemColumns = $allColumns |
    Where-Object { $_.tableName -like "*Build*" -or $_.tableName -like "*Database*" -or `
            $_.tableName -like "*Error*" -or $_.columnName -like "*ModifiedDate*" -or `
            $_.columnName -like "*Flag*" }

$systemCategories = @{
    "Sensitivity"      = @("System")
    "Information Type" = @("Other")
}

Set-Classification -columns $systemColumns -categories $systemCategories


# there's some commercially sensitive stuff
$commercialColumns = $allColumns | Where-Object { $_.tableName -like '*Vendor*' }

$commercialCategories = @{
    "Sensitivity" = @("Highly Confidential")
}

Set-Classification -columns $commercialColumns -categories $commercialCategories

#sales staff
$salesStaffColumns = $allColumns | Where-Object { $_.tableName -like '*SalesPerson*' }

$salesStaffCategories = @{
    "Sensitivity" = @("Highly Confidential")
}

Set-Classification -columns $salesStaffColumns -categories $salesStaffCategories

# and some information about employees which is sensitive
$employeeColumns = $allColumns |
    Where-Object { $_.columnName -eq 'Resume' -or $_.columnName -like '*SickLeave*' -or `
            $_.tableName -like '*PayHistory*' -or $_.tableName -eq 'Shift' -or `
            $_.columnName -like '*Marital*' -and $_.columnName -ne 'RateChangeDate' }

$employeeCategories = @{
    "Sensitivity" = @("Confidential - GDPR")
    "Owner"       = @("HR Manager")
}

Set-Classification -columns $employeeColumns -categories $employeeCategories

#
# I also want to set my Ownership tags (which I've added in my taxonomy)
# This is mostly set by schema.
#

$hrColumns = $allColumns |
    Where-Object { $_.schemaName -eq "HumanResources" -or $_.schemaName -eq "People" }

$hrCategories = @{
    "Owner" = @("HR Manager")
}

Set-Classification -columns $hrColumns -categories $hrCategories


$salesColumns = $allColumns |
    Where-Object { $_.schemaName -eq "Sales" -or $_.schemaName -eq "Purchasing" }

$salesCategories = @{
    "Owner" = @("Finance Manager")
}

Set-Classification -columns $salesColumns -categories $salesCategories

$prodColumns = $allColumns | Where-Object { $_.schemaName -eq "Production" }

$prodCategories = @{
    "Owner" = @("Operations")
}

Set-Classification -columns $prodColumns -categories $prodCategories

# The dbo schema has deployment and error information, so IT owns those under the CTO.

$itopsColumns = $allColumns | Where-Object { $_.schemaName -eq "dbo" }


$itopsCategories = @{
    "Owner" = @("Operations")
}

Set-Classification -columns $itopsColumns -categories $itopsCategories

# The rest of it is public information. Hit the api again to refresh the list,
# then set remaining columns to sensitivity = 'Public'

$untaggedColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName |
    Where-Object { -not $_.sensitivitylabel }

$untaggedCategories = @{
    "Sensitivity" = @("Public")
}

Set-Classification -columns $untaggedColumns -categories $untaggedCategories
