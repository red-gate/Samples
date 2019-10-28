# Script to deliver clone databases using the SQL Clone cmdlets,
# then register the new clone databases in SQL Data Catalog

$dataCatalogAuthToken = "[Your auth token]"
$catalogServerName = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

Invoke-WebRequest -Uri "$catalogServerName/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $dataCatalogAuthToken" }
Import-Module .\data-catalog.psm1 -Force

# Connect to SQL Clone server
$SQLCloneServer = "http://mysqlcloneserver.mydomain.com:14145"
Connect-SqlClone -ServerUrl $SQLCloneServer

# Reference to image
$Image = Get-SqlCloneImage -Name 'MySQLCLoneImage'

$ImageSourceInstance = $Image.OriginServerName + '.mydomain.com'
$ImageSourceDatabase = $Image.OriginDatabaseName

# I have several SQL Server instances registered on my SQL Clone Server - I want to deliver a copy to all of them
$Destinations = Get-SqlCloneSqlServerInstance |
    Where-Object -FilterScript { $_.Server -like '*WKS*' -and $_.Instance -eq 'Dev' }

$Template = Get-SqlCloneTemplate -Image $Image -Name "Drop masking tables"

# Create clone Dbs for Devs
$CloneName = 'mydatabase - clone'

"Started at {0}, creating clone databases for image ""{1}""" -f $(Get-Date) , $Image.Name

$Destinations |
    ForEach-Object {
        $Image |
            New-SqlClone -Name $CloneName -Template $Template -Location $_ |
            Wait-SqlCloneOperation
    }

# Connect to SQL Data Catalog
Connect-SqlDataCatalog -AuthToken $dataCatalogAuthToken -ServerUrl $catalogServerName

# Register clones in Data Catalog by updating the instance (forcing a scan)
$Destinations |
    ForEach-Object {
        $machineInstance = $_.Machine.MachineName.ToString() + "\" + $_.Instance.ToString()
        Start-ClassificationInstanceScan -FullyQualifiedInstanceName $machineInstance
    }

# Copy classification for clones
$Destinations |
    ForEach-Object {
        $machineInstance = $_.Machine.MachineName.ToString() + "\" + $_.Instance.ToString()
        Copy-Classification -sourceInstanceName $ImageSourceInstance -sourceDatabaseName $ImageSourceDatabase `
            -destinationInstanceName $machineInstance -destinationDatabaseName $CloneName
    }
