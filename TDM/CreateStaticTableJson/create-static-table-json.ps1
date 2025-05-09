# To run this script from Windows command prompt:
# powershell -ep bypass ./create-static-table-json.ps1

# Input file containing the list of tables
$inputFile = "c:\dev\DataGeneration\AdHocTestStuff\20250501-subsetting\explain.txt"

# Read the file and filter lines that match the "schema.table" format
$lines = Get-Content $inputFile | Where-Object { $_ -match '^\s*(\w+)\.(\w+)\s*$' }

# Initialize an array to hold the JSON objects
$jsonArray = @()

# Process each line and extract schema and table name
foreach ($line in $lines) {
    if ($line -match '^\s*(\w+)\.(\w+)\s*$') {
        $schema = $matches[1]
        $table = $matches[2]

        # Create a JSON object for the table
        $jsonObject = @{
            name     = $table
            schema   = $schema
            behavior = "copy"
        }

        # Add the object to the array
        $jsonArray += $jsonObject
    }
}

# Convert the array to JSON and output it
$jsonOutput = @{
    tables = $jsonArray
} | ConvertTo-Json -Depth 2

# Print the JSON to the console
Write-Output $jsonOutput