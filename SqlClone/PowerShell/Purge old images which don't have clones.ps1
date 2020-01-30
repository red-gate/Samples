##########################################################################################
# Purge old images which don't have clones.ps1 - version 0.1
# Purpose: If you are regularly creating images on a schedule, you may wish to clear out 
#          the older ones. This script will remove images older than a given date, as long
#          as they don't have clone databases dependent on them (in which case warn in the 
#          output).
# Warning: This script will remove images without any further warning. You will need to 
#          test this and add protections appropriate to your environment before live use.
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145'
$MachineName = 'WIN201601'
$InstanceName = 'SQL2014'
$ImageLocation = '\\red-gate\data-images'
$DatabaseName = 'AdventureWorks'
$PermissionsScriptPath = '\\red-gate\data-scripts\change-permissions.sql'
$MaskingSetPath = '\\red-gate\masking-sets\clean-pii-data.dmsmaskset'
$ImageTimeToLiveDays = 7;

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl

$oldImages = Get-SqlCloneImage | Where-Object {$_.CreatedDate -le (Get-Date).AddDays(0-$imageTimeToLiveDays)}

foreach ($image in $oldImages)
{
    $clones = Get-SqlClone -Image $image
     
    if (!($clones -eq $null))
    {
        "Will not remove image {0} because it has {1} dependent clone(s)." -f $image.Name, $clones.Count
    }
    else
    {
        Remove-SqlCloneImage -Image $image
        "Removed image {0}." -f $image.Name
    }
}