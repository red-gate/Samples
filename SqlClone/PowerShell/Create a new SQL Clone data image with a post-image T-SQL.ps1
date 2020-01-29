##########################################################################################
# Create a new SQL Clone data image with a post-image T-SQL.ps1 - version 0.1
# Purpose: Script to create a new SQL Clone data image with some additional post-image 
#          T-SQL run on the result.
# Warning: Clone Agent will attach the image files directly to the SQL Server instance 
#          being used to create it (either the instance it came from for an image from SQL 
#          Server, or the temporary instance for an image from a backup file).
##########################################################################################

Connect-SqlClone -ServerUrl 'http://sql-clone.example.com:14145'
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName WIN201601 -InstanceName SQL2014
$ImageDestination = Get-SqlCloneImageLocation -Path '\\red-gate\data-images'

$EmailRedactionScript = New-SqlCloneSqlScript -Sql "UPDATE Person.EmailAddress SET EmailAddress=N'removed@example.com'"
$PhoneRedactionScript = New-SqlCloneSqlScript -Sql "UPDATE Person.PersonPhone SET PhoneNumber=N'000-000-0000'"

$ImageOperation = New-SqlCloneImage -Name "AdventureWorks-$(Get-Date -Format yyyyMMddHHmmss)-PartiallyCleansed" `
    -SqlServerInstance $SqlServerInstance `
    -DatabaseName 'AdventureWorks' `
    -Destination $ImageDestination `
    -Modifications @($EmailRedactionScript, $PhoneRedactionScript)

Wait-SqlCloneOperation -Operation $ImageOperation