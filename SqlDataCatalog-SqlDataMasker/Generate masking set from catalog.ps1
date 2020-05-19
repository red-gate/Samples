$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }

Import-Module .\data-catalog.psm1 -Force

Import-Module .\DataMaskerHelpers.psm1 -Force

# connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# local config
$instanceName = 'sql-server1.domain.com'
$databaseName = 'AdventureWorks'

# a masking set file that will be created by this script.
$maskingSetPath = "AdventureWorks.DMSMaskSet"


# Generate the masking file.  Requires Data masker version >= 7.0.17
if (-not (Test-Path -Path "C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe" -PathType leaf)) {
    throw "To use this script, please install Data Masker for SQL Server version 7.0.17 or later"
}
& 'C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe' build using-windows-auth -m $maskingSetPath -l C:\Scripts\Logs -i $instanceName -d $databaseName


# Initial masking set file
$maskingDataSetTagCategoryId = ((Get-ClassificationTaxonomy).TagCategories |
        Where-Object { $_.Name -eq "Masking Data Set" }).id
Write-Output "Getting columns"

$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName

Write-Output "Finished getting columns"
[xml]$maskingSet = Get-Content -Path $maskingSetPath

$nextRuleNumber = 1 + (Get-HighestRuleId -MaskingSet $maskingSet)

# iterate through schemas -> tables -> columns
$schemas = $allColumns | Group-Object -Property schemaName

foreach ($schema in $schemas) {
    $schemaName = $schema.Name

    if (-not (Test-ControllerExists -MaskingSet $maskingSet -Schema $schemaName)) {
        Write-Output "No controller found for Catalog schema $schemaName. Skipping."
        continue
    }

    # all rules for this schema will need to know the controller's serialized id
    $controllerSerializedId = Format-ControllerSerializedId -MaskingSet $maskingSet -Schema $schemaName

    $tables = $schema.Group |
        Group-Object -Property tableName

    foreach ($table in $tables) {

        $tableName = $table.Name

        if (-not (Test-TableExists -MaskingSet $maskingSet -Schema $schemaName -Table $tableName)) {
            Write-Output "Table $tableName not found in schema $schemaName. Skipping."
            continue
        }

        $haveFoundColumnsWithDataSets = $false

        # use one substitution rule per table, constructed by modifying a template
        $substitutionRuleXml = Format-SubstitutionRule -RuleBlock 1 -RuleNumber $nextRuleNumber `
            -SerializedParentRuleId $controllerSerializedId -Table $tableName `
            -Description "Substitution rule for $tableName"

        $columns = $table.Group | Group-Object -Property columnName

        foreach ($column in $columns) {
            $columnName = $column.Name

            if (-not
                (Test-ColumnExists -MaskingSet $maskingSet `
                        -Schema $schemaName -Table $tableName -Column $columnName)) {
                Write-Output "Column $columnName not found in table $schemaName.$tableName. Skipping."
                continue
            }

            # update the column's plan type & comments in the controller based on sensitivity level
            $sensitivity = $column.Group |
                Select-Object -ExpandProperty sensitivityLabel -First 1

            $maskingSet = Update-PlanInformation -MaskingSet $maskingSet -Schema $schemaName `
                -Table $tableName -Column $columnName -Sensitivity $sensitivity

            # add the column to a masking rule if a data set label has been selected
            $dataSetLabel = $column.Group |
                Select-Object -ExpandProperty tags |
                Where-Object { $_.categoryId -eq $maskingDataSetTagCategoryId } |
                Select-Object -ExpandProperty name

            if (-not $dataSetLabel) {
                continue
            }

            # construct info for each classified column by modifying a template,
            # to add to this table's substitution rule
            Write-Output "Generating masking xml for column $column in table $table."
            $columnXml = Format-ColumnInfo -MaskingSet $maskingSet `
                -Schema $schemaName -Table $tableName -Column $columnName

            # if we can find a data set to use, add it to the column
            # and add the column to the substitution rule
            $dataSetXml = Get-DataSet -DataSetLabel $dataSetLabel
            if (-not $dataSetXml) {
                Write-Output "Data set $dataSetLabel doesn't exist "
                + "for column $schemaName.$tableName.$columnName. Skipping."

                continue
            }

            $substitutionRuleXml = Add-ColumnToSubstitutionRule `
                -SubstitutionRule $substitutionRuleXml -Column $columnXml -DataSet $dataSetXml
            $haveFoundColumnsWithDataSets = $true
        }

        if ($haveFoundColumnsWithDataSets) {
            $maskingSet = Add-RuleToMaskingSet -MaskingSet $maskingSet -Rule $substitutionRuleXml
            $nextRuleNumber++
        }
    }
}

$maskingSet.Save("$PSScriptRoot\$maskingSetPath") | Write-Output

Write-Output "Masking set generated as $PSScriptRoot\$maskingSetPath\n"
Get-ChildItem $PSScriptRoot\$maskingSetPath | Write-Output
