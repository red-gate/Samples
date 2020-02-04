##########################################################################################
# Create a new SQL Clone data image with a post-image T-SQL.ps1 - version 0.1
# Purpose: Script to create a new SQL Clone data image with some additional post-image 
#          T-SQL run on the result.
# Warning: Clone Agent will attach the image files directly to the SQL Server instance 
#          being used to create it (either the instance it came from for an image from SQL 
#          Server, or the temporary instance for an image from a backup file).
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145' # Set to your Clone server URL
$MachineName = 'WIN201601' # The machine name of the SQL Server instance to create the clones on
$InstanceName = 'SQL2014' # The instance name of the SQL Server instance to create the clones on
$ImageLocation = '\\red-gate\data-images' # Point to the file share we want to use to store the image
$DatabaseName = 'AdventureWorks' # The name of the database

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $MachineName -InstanceName $InstanceName
$ImageDestination = Get-SqlCloneImageLocation -Path $ImageLocation

$EmailRedactionScript = New-SqlCloneSqlScript -Sql "UPDATE Person.EmailAddress SET EmailAddress=N'removed@example.com'"
$PhoneRedactionScript = New-SqlCloneSqlScript -Sql "UPDATE Person.PersonPhone SET PhoneNumber=N'000-000-0000'"

$ImageOperation = New-SqlCloneImage -Name "$DatabaseName-$(Get-Date -Format yyyyMMddHHmmss)-PartiallyCleansed" `
    -SqlServerInstance $SqlServerInstance `
    -DatabaseName $DatabaseName `
    -Destination $ImageDestination `
    -Modifications @($EmailRedactionScript, $PhoneRedactionScript)

Wait-SqlCloneOperation -Operation $ImageOperation