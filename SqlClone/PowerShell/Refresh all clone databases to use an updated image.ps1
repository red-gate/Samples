##########################################################################################
# Refresh all clone databases to use an updated image.ps1 - version 0.1
# Purpose: If you are regularly creating images so that you have a latest possible copy 
#          of a database available, you may want to migrate clones to that new image. This
#          script will remove existing clone databases for a named image, then create 
#          new clone databases in the same location for an updated image.
# Warning: The clone databases will be removed immediately by this script, and any changes
#          made to them will be lost. The old image will also be removed.
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145'
$ImageName = 'Forex_20170301'
$NewImageName = 'Forex_20170302'

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl

$oldImage = Get-SqlCloneImage -Name $ImageName
$newImage = Get-SqlCloneImage -Name $NewImageName

$oldClones = Get-SqlClone | Where-Object {$_.ParentImageId -eq $oldImage.Id}

foreach ($clone in $oldClones)
{
    $thisDestination = Get-SqlCloneSqlServerInstance | Where-Object {$_.Id -eq $clone.LocationId}

    Remove-SqlClone $clone | Wait-SqlCloneOperation

    "Removed clone ""{0}"" from instance ""{1}"" " -f $clone.Name , $thisDestination.Server + '\' + $thisDestination.Instance;

    $newImage | New-SqlClone -Name $clone.Name -Location $thisDestination  | Wait-SqlCloneOperation

    "Added clone ""{0}"" to instance ""{1}"" " -f $clone.Name , $thisDestination.Server + '\' + $thisDestination.Instance;

}

# Remove the old image
Remove-SqlCloneImage -Image $oldImage;