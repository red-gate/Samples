##########################################################################################
# Remove all clones for an image.ps1 - version 0.1
# Purpose: You may wish to 'purge' the clone databases which have been created from a 
#          given image. You can run this from any machine which has the PowerShell 
#          cmdlets installed, and where the caller has access to perform SQL Clone 
#          operations.
# Warning: The clone databases will be removed immediately by this script, and any changes
#          made to them will be lost.
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145' # Set to your Clone server URL
$ImageName = '[Your Image Name]' # The name of the image to remove clones from

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl
$image = Get-SqlCloneImage -Name $ImageName

$clones = Get-SqlClone -Image $image

$elapsed = [System.Diagnostics.Stopwatch]::StartNew()

"Started at {0}, removing {1} clones for image ""{2}""" -f $(get-date) , $clones.Count , $image.Name

$clones | ForEach-Object { # note - '{' needs to be on same line as 'ForEach-Object' !
    $_ | Remove-SqlClone | Wait-SqlCloneOperation
    "Removed clone ""{0}""" -f $_.Name ;
};
"Total Elapsed Time: {0}" -f $($elapsed.Elapsed.ToString())