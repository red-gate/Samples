param (
    $sqlSourceHost = "localhost",
    $sqlSourcePort = "",
    $sqlSourceDatabaseName = "AdventureWorksLT2022",
    $sqlSourceUser = "",
    $sqlSourcePassword = "",
    $sqlTargetHost = "localhost",
    $sqlTargetPort = "",
    $sqlTargetDatabaseName = "AdventureWorksLT2022_Target",
    $sqlTargetUser = "",
    $sqlTargetPassword = "",
    $odbcDriver = "ODBC+Driver+18+for+SQL+Server",
    [switch]$classify = $false,
    [switch]$plan = $false,
    [switch]$populate = $false
)

$currentFolder = (Get-Item .).FullName
Write-Output "Current folder: $currentFolder"

# Connection strings
$sqlAlchemyPrefix = "mssql+pyodbc"

# SOURCE
if ($sqlSourcePort -like "") {
    $sqlSourceHostPort_DotNet = $sqlSourceHost
    $sqlSourceHostPort_SqlAlchemy = $sqlSourceHost
}
else {
    # DotNet connection strings require a comma between host and port
    $sqlSourceHostPort_DotNet = "$sqlSourceHost,$sqlSourcePort"
    # SqlAlchemy connection string URLs require a colon between host and port
    $sqlSourceHostPort_SqlAlchemy = "${sqlSourceHost}:$sqlSourcePort"
}

if (($sqlSourceUser -like "") -and ($sqlSourcePassword -like "")){
    # No username and password: Use Windows authentication
    $sourceConnection_DotNet = "server=$sqlSourceHostPort_DotNet;database=$sqlSourceDatabaseName;Trusted_Connection=yes;TrustServerCertificate=yes"
    $sourceConnection_SqlAlchemy = "${sqlAlchemyPrefix}://@${sqlSourceHostPort_SqlAlchemy}/${sqlSourceDatabaseName}?trusted_connection=yes&TrustServerCertificate=yes&driver=$odbcDriver"
}
else {
    $sourceConnection_DotNet = "server=$sqlSourceHostPort_DotNet;database=$sqlSourceDatabaseName;TrustServerCertificate=yes;User Id=$sqlSourceUser;Password=$sqlSourcePassword;"

    # SqlAlchemy database connection URL must be URL encoded in case password has characters like @ or /
    $sqlSourcePasswordSqlAlchemy = [uri]::EscapeDataString($sqlSourcePassword)

    $sourceConnection_SqlAlchemy = "${sqlAlchemyPrefix}://${sqlSourceUser}:${sqlSourcePasswordSqlAlchemy}@${sqlSourceHostPort_SqlAlchemy}${sqlPort_SqlAlchemy}/${sqlSourceDatabaseName}?&TrustServerCertificate=yes&driver=$odbcDriver"
}

# TARGET
if ($sqlTargetPort -like "") {
    $sqlTargetHostPort_DotNet = $sqlTargetHost
    $sqlTargetHostPort_SqlAlchemy = $sqlTargetHost
}
else {
    # DotNet connection strings require a comma between host and port
    $sqlTargetHostPort_DotNet = "$sqlTargetHost,$sqlTargetPort"
    # SqlAlchemy connection string URLs require a colon between host and port
    $sqlTargetHostPort_SqlAlchemy = "${sqlTargetHost}:$sqlTargetPort"
}

if (($sqlTargetUser -like "") -and ($sqlTargetPassword -like "")){
    # No username and password: Use Windows authentication
    $TargetConnection_DotNet = "server=$sqlTargetHostPort_DotNet;database=$sqlTargetDatabaseName;Trusted_Connection=yes;TrustServerCertificate=yes"
    $TargetConnection_SqlAlchemy = "${sqlAlchemyPrefix}://@${sqlTargetHostPort_SqlAlchemy}/${sqlTargetDatabaseName}?trusted_connection=yes&TrustServerCertificate=yes&driver=$odbcDriver"
}
else {
    $TargetConnection_DotNet = "server=$sqlTargetHostPort_DotNet;database=$sqlTargetDatabaseName;TrustServerCertificate=yes;User Id=$sqlTargetUser;Password=$sqlTargetPassword;"

    # SqlAlchemy database connection URL must be URL encoded in case password has characters like @ or /
    $sqlTargetPasswordSqlAlchemy = [uri]::EscapeDataString($sqlTargetPassword)

    $TargetConnection_SqlAlchemy = "${sqlAlchemyPrefix}://${sqlTargetUser}:${sqlTargetPasswordSqlAlchemy}@${sqlTargetHostPort_SqlAlchemy}${sqlPort_SqlAlchemy}/${sqlTargetDatabaseName}?&TrustServerCertificate=yes&driver=$odbcDriver"
}

Write-Output "PS version: $($PSVersionTable.PSVersion)"
Write-Output ""
Write-Output "Source Connection string (DotNet):"
Write-Output "$sourceConnection_DotNet"
Write-Output ""
Write-Output "Source Connection string (SqlAlchemy):"
Write-Output "$sourceConnection_SqlAlchemy"
Write-Output ""
Write-Output "Target Connection string (DotNet):"
Write-Output "$targetConnection_DotNet"
Write-Output ""
Write-Output "Target Connection string (SqlAlchemy):"
Write-Output "$targetConnection_SqlAlchemy"

if ($classify) {
    Write-Output ""
    Write-Output "CLASSIFY: creating a classification.json file in $currentFolder"
    .\rganonymize classify --database-engine SqlServer --connection-string="$sourceConnection_DotNet" --classification-file "$currentFolder\classification.json" --output-all-columns
}

if ($plan) {
    Write-Output ""
    Write-Output "PLAN: creating a generation.json file in $currentFolder"
    # .\rggenerate plan --connection-string "$targetConnection_SqlAlchemy" --classification-file "$currentFolder\classification.json" --generation-file "$currentFolder\generation.json" --options-file "rggenerate-options.json" --agree-to-eula
    .\rggenerate plan --connection-string "$targetConnection_SqlAlchemy" --generation-file "$currentFolder\generation.json" --options-file "rggenerate-options.json" --log-folder "$currentFolder\logs" --agree-to-eula
}

if ($populate) {
    Write-Output ""
    Write-Output "POPULATE: generating data into database"
    .\rggenerate populate --source-connection-string "$sourceConnection_SqlAlchemy" --target-connection-string "$targetConnection_SqlAlchemy" --generation-file "$currentFolder\generation.json" --options-file "rggenerate-options.json" --log-folder "$currentFolder\logs" --agree-to-eula
}
