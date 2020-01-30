##########################################################################################
# Create an image for the latest backup.ps1 - version 0.1
# Purpose: One key use case for SQL Clone is to have the latest possible copy of a
#          production database available for quick mounting in another environment. For a
#          backup file matching a database name, this script obtains the latest then uses
#          it to create a SQL Clone image.
# Warning: You need to provide a SQL Clone Agent to perform the operation, but you only 
#          need the disk space for the database to be available in the final destination
#         (the operation uses a virtual mount point into that location).
##########################################################################################

$ServerUrl = 'http://sql-clone.example.com:14145' # Set to your Clone server URL
$MachineName = 'WIN201601' # The machine name of the SQL Server instance to create the clones on
$InstanceName = 'SQL2014' # The instance name of the SQL Server instance to create the clones on
$ImageLocation = '\\red-gate\data-images' # Point to the file share we want to use to store the image
$DatabaseName = 'AdventureWorks' # The name of the database
$BackupFolder = '\\File1.example.com\Backups\SQL\MSSQL\Backup' # The path to the database backup folder

##########################################################################################

Connect-SqlClone -ServerUrl $ServerUrl

$TemporaryServer = Get-SqlCloneSqlServerInstance -MachineName $MachineName -InstanceName $InstanceName # You can omit the instance parameter if there is only one instance

if (!(Test-Path ($BackupFolder)))
  {
    write-host 'Backup folder not found. Exiting.'
    break
  }

# Get the latest backup file for our database (striped backups would be more complex)
$BackupFiles = Get-ChildItem -Path $BackupFolder  |
    Where-Object -FilterScript { $_.Name.Substring(0,$DatabaseName.Length) -eq $DatabaseName}   # My backup files always start with the database name

# Now we have a filtered list, sort to get latest
$BackupFile = $BackupFiles |
    Sort-Object -Property LastWriteTime  |   
    Select-Object -Last 1 # I only want the most recent file for this database to be used

$BackupFileName = $BackupFile.FullName

#Start a timer
$elapsed = [System.Diagnostics.Stopwatch]::StartNew()

"Started at {0}, creating data image for database ""{1}"" from backup file ""{2}""" -f $(get-date) , $DatabaseName , $BackupFileName

$DataImageName = $DatabaseName + "_" + (Get-Date -Format "yyyyMMdd") # Prepare a name for the data image, with a timestamp
$ImageDestination = Get-SqlCloneImageLocation -Path $ImageLocation

New-SqlCloneImage -Name $DataImageName -SqlServerInstance $TemporaryServer -BackupFileName $BackupFileName -Destination $ImageDestination | Wait-SqlCloneOperation # Create the data image and wait for completion

"Total Elapsed Time: {0}" -f $($elapsed.Elapsed.ToString())