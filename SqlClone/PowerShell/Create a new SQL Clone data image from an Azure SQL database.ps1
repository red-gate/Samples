# This script requires both SQL CLone PowerShell and Azure PowerShell modules and assumes that the database and the storage account are under the same ResourceGroup

#Variables to be used in the script
$AzureResourceGroupName = 'YourAzureResourceGroupName' 
$AzureSQLServerName = 'YourAzureSQLServerName' 
$AzureSQLDatabaseName = 'YourAzureSQLDatabaseName' 
$AzureStorageAccountName = 'YourAzureStorageAccountName'
$AzureStorageURI = "YourAzureStorageURI"
$AzureStorageKey = "YourAzureStorageKey"
$AzureStorageContainer = 'YourAzureStorageContainer'
$AzureDatabaseAdminLogin = "YourAdminLogin"
$AzureDatabaseAdminLoginPassword = ConvertTo-SecureString "YourAzureDatabaseAdminLoginPassword" -AsPlainText -Force
$BacPacBlobName = "YourBacPacBlobName.bac"
$LocalSQLServer = "YourLocalSQLServer"
$RestoredDatabaseName = 'RestoredDatabaseName'
$SQLCloneServerUrl = 'YourSQLCloneServerUrl'
$CurrentMachine = 'YourCurrentMachine'
$InstanceName = 'YourInstanceName'
$ImageSharePath = 'YourImageSharePath'
$ImageName = 'YourImageName'

#Connect to Azure Account and set subscription context
Connect-AzAccount 
Set-AzContext -SubscriptionId 'YourSubscriptionId'

# Start export of SQL DB
$ExportRequest = New-AzSqlDatabaseExport -DatabaseName $AzureSQLDatabaseName `
-ServerName $AzureSQLServerName `
-StorageKeyType "storageaccesskey" `
-StorageKey $AzureStorageKey `
-StorageUri $AzureStorageURI `
-ResourceGroupName $AzureResourceGroupName `
-AdministratorLogin $AzureDatabaseAdminLogin `
-AdministratorLoginPassword $AzureDatabaseAdminLoginPassword

# Wait for export to complete
$ExportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
Write-Output "Exporting"
while ($ExportStatus.Status -ne "Completed")
{
    $ExportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
    Write-Output "Export in progress"
    Start-Sleep -s 10
}
Write-Output $ExportStatus

# Download the bacpac file
Write-Output "Downloading bacpac file"
$StorageContext = New-AzStorageContext -StorageAccountName $AzureStorageAccountName -StorageAccountKey $AzureStorageKey
Get-AzStorageBlobContent -Container $AzureStorageContainer -Blob $BacPacBlobName -Context $StorageContext -Destination "C:\temp\BACPACS"

# Import BacPac file as data tier application
$fileExe = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\150\sqlpackage.exe"
$bacpacname = "C:\temp\BACPACS\"+ $BacPacBlobName 
& $fileExe /a:Import /sf:$bacpacname /tdn:$RestoredDatabaseName /tsn:$LocalSQLServer

#Mask and Provision the copy
# Connect to SQL Clone Server
Connect-SqlClone -ServerUrl $SQLCloneServerUrl

# Set variables for Image and Clone Location
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $CurrentMachine -InstanceName $InstanceName
$ImageDestination = Get-SqlCloneImageLocation -Path $ImageSharePath

# Create New Image from Clone
New-SqlCloneImage -Name $ImageName -SqlServerInstance $SqlServerInstance -DatabaseName $RestoredDatabaseName `
-Destination $ImageDestination | Wait-SqlCloneOperation

$Image = Get-SqlCloneImage -Name $ImageName

# Create New Clone
New-SqlClone -Image $Image -Name $ImageName -Location $SqlServerInstance 

#Drop the Temp Copy
Invoke-Sqlcmd  -ServerInstance $LocalSqlServer -Query "DROP DATABASE $BacPacBlobName;"
