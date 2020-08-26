############################################################################
# Pull the column template mappings using the new command
# Build the masking set from the resulting column template mappings
# 
############################################################################

$global:DataMaskerCommandLineName = 'DataMaskerCmdLine.exe'
$global:DataMaskerCommandLinePath = 'C:\Program Files\Red Gate\Data Masker for SQL Server 7'

function DataMaskerCommandLineExecutable {
    return Join-Path $global:DataMaskerCommandLinePath $global:DataMaskerCommandLineName
}

function Test-DataMaskerExists {
    If (-not (Test-Path "$DataMaskerCommandLinePath\$DataMaskerCommandLineName")) {
        throw "Could not find the Data Masker Command Line executable ($DataMaskerCommandLineName) in $DataMaskerCommandLinePath. If you have installed Data Masker into a non-standard directory, please use the Register-DataMaskerInstallation CmdLet to tell us where it is"
    }
}

function Register-DataMaskerInstallation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $InstalledCommandLinePath
    )

    If (-not (Test-Path "$InstalledCommandLinePath\$DataMaskerCommandLineName")) {
        throw "Could not find the Data Masker Command Line executable ($DataMaskerCommandLineName) in $InstalledCommandLinePath."
    }

    $global:DataMaskerCommandLinePath = $InstalledCommandLinePath
}

function Import-ColumnTemplateMapping {
    param (
        [Parameter(Mandatory)]
        [string]
        $CatalogUrl,

        [Parameter(Mandatory)]
        [string]
        $CatalogAuthToken,

        [Parameter(Mandatory)]
        [string]
        $SqlServerHostName,

        [Parameter(Mandatory)]
        [string]
        $DatabaseName,

        [Parameter(Mandatory)]
        [string]
        $InformationTypeCategory,

        [Parameter(Mandatory)]
        [string]
        $SensitivityCategory,

        [Parameter(Mandatory)]
        [string]
        $SensitivityTag,

        [Parameter(Mandatory)]
        [string]
        $MappingFilePath,

        [Parameter(Mandatory)]
        [string]
        $LogDirectory
    )

    & (DataMaskerCommandLineExecutable) column-template build-mapping-file `
        --catalog-uri $CatalogUrl `
        --api-key $CatalogAuthToken `
        --instance $SqlServerHostName `
        --database $DatabaseName `
        --information-type-category $InformationTypeCategory `
        --sensitivity-category $SensitivityCategory `
        --sensitivity-tag $SensitivityTag `
        --mapping-file $MappingFilePath `
        --log-directory $LogDirectory
        
    if ($LASTEXITCODE -ne 0) {
        throw "Data Masker failed with exit code $LASTEXITCODE. See log files for details."
    }
}

function ConvertTo-MaskingSetUsingWindowsAuth {
    param (
        [Parameter(Mandatory)]
        [string]
        $OutputMaskingSetFilePath,

        [Parameter(Mandatory)]
        [string]
        $LogDirectory,

        [Parameter(Mandatory)]
        [string]
        $SqlServerHostName,

        [Parameter(Mandatory)]
        [string]
        $DatabaseName,

        [Parameter(Mandatory)]
        [string]
        $InputMappingFilePath
    )

    $ParFilePath = $OutputMaskingSetFilePath + ".Parfile"
    
    & (DataMaskerCommandLineExecutable) build using-windows-auth `
        --masking-set-file $OutputMaskingSetFilePath `
        --log-directory $LogDirectory `
        --instance $SqlServerHostName `
        --database $DatabaseName `
        --mapping-file $InputMappingFilePath `
        --parfile $ParFilePath
    
    if ($LASTEXITCODE -ne 0) {
        throw "Data Masker failed with exit code $LASTEXITCODE. See log files for details."
    }
    
    return $ParFilePath
}

function ConvertTo-MaskingSetUsingSqlAuth {
    param (
        [Parameter(Mandatory)]
        [string]
        $DatabaseUserName,

        [Parameter(Mandatory)]
        [string]
        $DatabaseUserPassword,

        [Parameter(Mandatory)]
        [string]
        $OutputMaskingSetFilePath,

        [Parameter(Mandatory)]
        [string]
        $LogDirectory,

        [Parameter(Mandatory)]
        [string]
        $SqlServerHostName,

        [Parameter(Mandatory)]
        [string]
        $DatabaseName,

        [Parameter(Mandatory)]
        [string]
        $InputMappingFilePath
    )

    $ParFilePath = $OutputMaskingSetFilePath + ".Parfile"
    
    & (DataMaskerCommandLineExecutable) build using-sql-auth `
        --username $DatabaseUserName `
        --password $DatabaseUserPassword `
        --masking-set-file $OutputMaskingSetFilePath `
        --log-directory $LogDirectory `
        --instance $SqlServerHostName `
        --database $DatabaseName `
        --mapping-file $InputMappingFilePath `
        --parfile $ParFilePath

    if ($LASTEXITCODE -ne 0) {
        throw "Data Masker failed with exit code $LASTEXITCODE. See log files for details."
    }
    
    return $ParFilePath
}

function Invoke-MaskDatabase {
    param (
        [Parameter(Mandatory)]
        [string]
        $ParameterFile
    )

    DataMaskerCommandLineExecutable run --parfile $ParameterFile 
}

function Get-MaskingTaxonomyTags {
    return @(
        "Title",
        "Given name",
        "Family name",
        "Full name",
        "Date of birth",
        "Gender",
        "Nationality",
        "Occupation",
        "Organization name",
        "Password",
        "Passport number",
        "Driving license number",
        "Photo",
        "Email address",
        "Phone number",
        "Street address",
        "City",
        "State",
        "ZIP code",
        "Full address",
        "County",
        "Country",
        "Bank account number",
        "Debit/credit card number",
        "Debit/credit card expiry date",
        "Social Security number",
        "URL"
    )
}

Export-ModuleMember Invoke-MaskDatabase
Export-ModuleMember ConvertTo-MaskingSetUsingSqlAuth
Export-ModuleMember ConvertTo-MaskingSetUsingWindowsAuth
Export-ModuleMember Import-ColumnTemplateMapping
Export-ModuleMember Register-DataMaskerInstallation
Export-ModuleMember Test-DataMaskerExists
Export-ModuleMember Get-MaskingTaxonomyTags