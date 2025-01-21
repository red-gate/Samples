param (
    $sqlHost = "localhost",
    $sqlPort = "",
    $sqlDatabaseName = "AdventureWorksLT2022",
    $sqlUser = "",
    $sqlPassword = "",
    $odbcDriver = "ODBC+Driver+18+for+SQL+Server",
    [switch]$classify = $false,
    [switch]$plan = $false,
    [switch]$populate = $false
)

$output = (Get-Item .).FullName
Write-Output "Output folder: $output"

# Connection strings
$sqlAlchemyPrefix = "mssql+pyodbc"

if ($sqlPort -like "") {
    $sqlHostPort_DotNet = $sqlHost
    $sqlHostPort_SqlAlchemy = $sqlHost
}
else {
    # DotNet connection strings require a comma between host and port
    $sqlHostPort_DotNet = "$sqlHost,$sqlPort"
    # SqlAlchemy connection string URLs require a colon between host and port
    $sqlHostPort_SqlAlchemy = "${sqlHost}:$sqlPort"
}

if (($sqlUser -like "") -and ($sqlPassword -like "")){
    # No username and password: Use Windows authentication
    $connection_DotNet = "server=$sqlHostPort_DotNet;database=$sqlDatabaseName;Trusted_Connection=yes;TrustServerCertificate=yes"
    $connection_SqlAlchemy = "${sqlAlchemyPrefix}://@${sqlHostPort_SqlAlchemy}/${sqlDatabaseName}?trusted_connection=yes&TrustServerCertificate=yes&driver=$odbcDriver"
}
else {
    $connection_DotNet = "server=$sqlHostPort_DotNet;database=$sqlDatabaseName;TrustServerCertificate=yes;User Id=$sqlUser;Password=$sqlPassword;"

    # SqlAlchemy database connection URL must be URL encoded in case password has characters like @ or /
    $sqlPasswordSqlAlchemy = [uri]::EscapeDataString($sqlPassword)

    $connection_SqlAlchemy = "${sqlAlchemyPrefix}://${sqlUser}:${sqlPasswordSqlAlchemy}@${sqlHostPort_SqlAlchemy}${sqlPort_SqlAlchemy}/${sqlDatabaseName}?&TrustServerCertificate=yes&driver=$odbcDriver"
}

Write-Output "PS version: $($PSVersionTable.PSVersion)"
Write-Output ""
Write-Output "Connection string (DotNet):"
Write-Output "$connection_DotNet"
Write-Output ""
Write-Output "Connection string (SqlAlchemy):"
Write-Output "$connection_SqlAlchemy"

if ($classify) {
    Write-Output ""
    Write-Output "CLASSIFY: creating a classification.json file in $output"
    .\rganonymize classify --database-engine SqlServer --connection-string="$connection_DotNet" --classification-file "$output\classification.json" --output-all-columns
}

if ($plan) {
    Write-Output ""
    Write-Output "PLAN: creating a generation.json file in $output"
    # .\rggenerate plan --connection-string "$connection_SqlAlchemy" --classification-file "$output\classification.json" --generation-file "$output\generation.json" --options-file "rggenerate-options.json" --agree-to-eula
    .\rggenerate plan --connection-string "$connection_SqlAlchemy" --generation-file "$output\generation.json" --options-file "rggenerate-options.json" --log-folder "$output\logs"--agree-to-eula
}

if ($populate) {
    Write-Output ""
    Write-Output "POPULATE: generating data into database"
    .\rggenerate populate --target-connection-string "$connection_SqlAlchemy" --generation-file "$output\generation.json" --options-file "rggenerate-options.json" --log-folder "$output\logs"--agree-to-eula
}
