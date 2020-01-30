##########################################################################################
# Create a new SQL Clone data image with both a Data Masker masking set and post-image 
# T-SQL.ps1 - version 0.1
# Purpose: Script to create a new SQL Clone data image with both a Data Masker masking set 
#          and post-image T-SQL on it.
# Warning: Clone Agent will attach the image files directly to the SQL Server instance 
#          being used to create it (either the instance it came from for an image from SQL
#          Server, or the temporary instance for an image from a backup file).
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145'
$MachineName = 'WIN201601'
$InstanceName = 'SQL2014'
$ImageLocation = '\\red-gate\data-images'
$DatabaseName = 'AdventureWorks'
$PermissionsScriptPath = '\\red-gate\data-scripts\change-permissions.sql'
$MaskingSetPath = '\\red-gate\masking-sets\clean-pii-data.dmsmaskset'

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $MachineName -InstanceName $InstanceName
$ImageDestination = Get-SqlCloneImageLocation -Path $ImageLocation

$MaskingSet = New-SqlCloneMask -Path $MaskingSetPath
$PermissionsScript = New-SqlCloneSqlScript -Path $PermissionsScriptPath

$ImageOperation = New-SqlCloneImage -Name "$DatabaseName-$(Get-Date -Format yyyyMMddHHmmss)-CleansedAndWithPermissionsChanges" `
    -SqlServerInstance $SqlServerInstance `
    -DatabaseName $DatabaseName `
    -Destination $ImageDestination `
    -Modifications @($MaskingSet, $PermissionsScript)

Wait-SqlCloneOperation -Operation $ImageOperation