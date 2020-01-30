##########################################################################################
# Create a new SQL Clone data image with a post-image T-SQL, loaded from files.ps1 
# - version 0.1
# Purpose: Script to create a new SQL Clone data image with some additional post-image 
#          T-SQL, loaded from files, run on the result
# Warning: Clone Agent will attach the image files directly to the SQL Server instance 
#          being used to create it (either the instance it came from for an image from SQL 
#          Server, or the temporary instance for an image from a backup file).
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145'
$MachineName = 'WIN201601'
$InstanceName = 'SQL2014'
$ImageLocation = '\\red-gate\data-images'
$DatabaseName = 'AdventureWorks'
$DropLargeTableScriptPath = '\\red-gate\data-scripts\drop-large-table.sql'
$PermissionsScriptPath = '\\red-gate\data-scripts\change-permissions.sql'

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $MachineName -InstanceName $InstanceName
$ImageDestination = Get-SqlCloneImageLocation -Path $ImageLocation

$DropBigTable = New-SqlCloneSqlScript -Path $DropLargeTableScriptPath
$PermissionsScript = New-SqlCloneSqlScript -Path $PermissionsScriptPath

$ImageOperation = New-SqlCloneImage -Name "$DatabaseName-$(Get-Date -Format yyyyMMddHHmmss)-PartiallyCleansedAndWithPermissionsChanges" `
    -SqlServerInstance $SqlServerInstance `
    -DatabaseName $DatabaseName `
    -Destination $ImageDestination `
    -Modifications @($DropBigTable, $PermissionsScript)

Wait-SqlCloneOperation -Operation $ImageOperation