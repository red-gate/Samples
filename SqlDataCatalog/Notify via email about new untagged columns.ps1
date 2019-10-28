# Script to send an email when untagged columns are discovered in a database registered in SQL Data Catalog

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL
$instanceName = 'sql-server1.domain.com'
$databaseName = "AdventureWorks"


Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# get all columns into a collection
$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName

# the definition used is that untaggedColumns have NO tags, NO sensitivity label and NO information type.
# you may need to adjust to suit your definition

$untaggedColumns = $allColumns |
    Where-Object { $_.tags.count -eq 0 -and !$_.sensitivityLabel -and !$_.informationType }

if ($untaggedColumns.Count -gt 0) {
    $text = $untaggedColumns |
        Format-List |
        Out-String
    $From = "SqlDataCatalog@your-domain.com"
    $To = "Jane.Doe@your-domain.com"
    $Subject = "Untagged column found in database $databaseName"
    $Body = $text.Normalize()
    $SMTPServer = "yourSmtpServer.your-domain.com"
    $SMTPPort = "25"
    Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body `
        -SmtpServer $SMTPServer -port $SMTPPort -DeliveryNotificationOption OnSuccess
}
else {
    "Started at {0}, NO untagged columns found. {1} total columns found" -f $(Get-Date) , $allColumns.Count
}
