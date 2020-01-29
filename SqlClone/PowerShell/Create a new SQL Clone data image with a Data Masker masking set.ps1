##########################################################################################
# Create a new SQL Clone data image with a Data Masker masking set.ps1 - version 0.1
# Purpose: Script to create a new SQL Clone data image and run a Data Masker masking set 
#          on it.
# Warning: Clone Agent will attach the image files directly to the SQL Server instance 
#          being used to create it (either the instance it came from for an image from SQL
#          Server, or the temporary instance for an image from a backup file).
##########################################################################################

Connect-SqlClone -ServerUrl 'http://sql-clone.example.com:14145'
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName WIN201601 -InstanceName SQL2014
$ImageDestination = Get-SqlCloneImageLocation -Path '\\red-gate\data-images'

$MaskingSet= New-SqlCloneMask -Path \\red-gate\masking-sets\clean-pii-data.dmsmaskset

$ImageOperation = New-SqlCloneImage -Name "AdventureWorks-$(Get-Date -Format yyyyMMddHHmmss)-Cleansed" `
    -SqlServerInstance $SqlServerInstance `
    -DatabaseName 'AdventureWorks' `
    -Destination $ImageDestination `
    -Modifications $MaskingSet

Wait-SqlCloneOperation -Operation $ImageOperation