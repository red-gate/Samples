##########################################################################################
# Create 'n' clones for an image.ps1 - version 0.1
# Purpose: This script will create as many clone databases as requested on a given agent.
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145' # Set to your Clone server URL
$MachineName = 'WIN201601' # The machine name of the SQL Server instance to create the clones on
$InstanceName = 'SQL2014' # The instance name of the SQL Server instance to create the clones on
$ImageName =  '[Your Image Name]' # The name of the image to clone

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl

$sqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $MachineName -InstanceName $InstanceName

$image = Get-SqlCloneImage -Name $ImageName

$ClonePrefix = '_SO_Clone'
$Count = 5 # or however many you want 

$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
"Started at {0}" -f $(get-date)

"OK, going to create {0} clones" -f $Count

for ($i=0;$i -lt $Count;$i++)
{
    $image | New-SqlClone -Name $ClonePrefix$i -Location $sqlServerInstance | Wait-SqlCloneOperation 
  "Created clone {0}" -f $i;  
};

"Total Elapsed Time: {0}" -f $($elapsed.Elapsed.ToString())