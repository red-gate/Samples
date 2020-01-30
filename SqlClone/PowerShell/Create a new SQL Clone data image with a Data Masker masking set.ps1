##########################################################################################
# Create a new SQL Clone data image with a Data Masker masking set.ps1 - version 0.1
# Purpose: Script to create a new SQL Clone data image and run a Data Masker masking set 
#          on it.
# Warning: Clone Agent will attach the image files directly to the SQL Server instance 
#          being used to create it (either the instance it came from for an image from SQL
#          Server, or the temporary instance for an image from a backup file).
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145'
$MachineName = 'WIN201601'
$InstanceName = 'SQL2014'
$ImageLocation = '\\red-gate\data-images'
$MaskingSetPath = '\\red-gate\masking-sets\clean-pii-data.dmsmaskset'
$DatabaseName = 'AdventureWorks'

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $MachineName -InstanceName $InstanceName
$ImageDestination = Get-SqlCloneImageLocation -Path $ImageLocation

$MaskingSet = New-SqlCloneMask -Path $MaskingSetPath

$ImageOperation = New-SqlCloneImage -Name "$DatabaseName-$(Get-Date -Format yyyyMMddHHmmss)-Cleansed" `
    -SqlServerInstance $SqlServerInstance `
    -DatabaseName $DatabaseName `
    -Destination $ImageDestination `
    -Modifications $MaskingSet

Wait-SqlCloneOperation -Operation $ImageOperation