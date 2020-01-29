##########################################################################################
# Create a clone on all connected SQL Server instances.ps1 - version 0.1
# Purpose: You may have a scenario in which you want a 'latest' copy of a database to be 
#          available on all SQL Server instances which are registered with SQL Clone.
##########################################################################################

Connect-SqlClone -ServerUrl 'http://sql-clone.example.com:14145'
$SourceDataImage = Get-SqlCloneImage -Name  'ImageName'
$CloneName = 'ImageName_Latest'

# I have multiple SQL Server instances registered on my SQL Clone Server - I want to deliver a copy to all of them
$Destinations = Get-SqlCloneSqlServerInstance

# Start a timer
$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
"Started at {0}, creating clone databases for image ""{1}""" -f $(get-date) , $SourceDataImage.Name
foreach ($Destination in $Destinations)
{
    $SourceDataImage | New-SqlClone -Name $CloneName -Location $Destination | Wait-SqlCloneOperation
    $ServerInstance = $Destination.Server + '\' +$Destination.Instance
    "Created clone in instance {0}" -f $Destination.Server + '\' + $Destination.Instance;  
}
"Total Elapsed Time: {0}" -f $($elapsed.Elapsed.ToString())