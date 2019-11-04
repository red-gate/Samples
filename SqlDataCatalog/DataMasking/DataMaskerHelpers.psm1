function Format-ControllerSerializedId {
    #construct the serialized id of a schema's controller for use within substitution rules
    Param(
        [xml]$MaskingSet,
        [string]$Schema
    )
    $controllerRuleBlock = $MaskingSet.SelectSingleNode("/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController[DMSSchemaEntity_Login/N2KSQLServerEntity_Login/SchemaName/@Value = `"$Schema`"]/DMSRule/RuleBlock/@Value").Value
    $controllerRuleNumber = $MaskingSet.SelectSingleNode("/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController[DMSSchemaEntity_Login/N2KSQLServerEntity_Login/SchemaName/@Value = `"$Schema`"]/DMSRule/RuleNumber/@Value").Value
    $controllerSerializedId = "$controllerRuleBlock-$controllerRuleNumber"
    return $controllerSerializedId
}
function Test-ControllerExists {
    Param(
        [xml]$MaskingSet,
        [string]$Schema
    )
    $controller = $MaskingSet.SelectSingleNode("DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login/SchemaName[@Value = `"$Schema`"]")
    if ($controller) {
        return $true
    }
    return $false
}

function Test-TableExists {
    Param(
        [xml]$MaskingSet,
        [string]$Schema,
        [string]$Table
    )
    $table = $MaskingSet.SelectSingleNode("DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table/TableName[@Value = `"$Table`"]")
    if ($table) {
        return $true
    }
    return $false
}

function Test-ColumnExists {
    Param(
        [xml]$MaskingSet,
        [string]$Schema,
        [string]$Table,
        [string]$Column
    )
    $column = $maskingSet.SelectSingleNode("DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table[TableName/@Value = `"$Table`"]/N2KSQLServerCollection_Column/DMSSchemaEntity_Column/N2KSQLServerEntity_Column[ColumnName/@Value = `"$Column`"]")
    if ($column) {
        return $true
    }
    return $false
}

function Add-ColumnToSubstitutionRule {
    Param(
        [xml]$SubstitutionRule,
        [xml]$Column,
        [xml]$DataSet
    )
    $dataSetElement = $Column.ImportNode($DataSet.SelectSingleNode('*'), $true)
    [void]$Column.SelectSingleNode('DMSPickedColumnAndDataSet').AppendChild($dataSetElement)
    $columnElement = $SubstitutionRule.ImportNode($Column.SelectSingleNode('DMSPickedColumnAndDataSet'), $true)
    [void]$SubstitutionRule.SelectSingleNode('RuleSubstitution/DMSPickedColumnAndDataSetCollection').AppendChild($columnElement)
    return $SubstitutionRule
}

function Add-RuleToMaskingSet {
    Param(
        [xml]$MaskingSet,
        [xml]$Rule
    )
    $ruleElement = $MaskingSet.ImportNode($Rule.SelectSingleNode('*'), $true)
    [void]$MaskingSet.SelectSingleNode('/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList').AppendChild($ruleElement)
    return $MaskingSet
}

function Get-HighestRuleId {
    Param(
        [xml]$MaskingSet
    )
    [int]$ruleId = ($maskingSet.SelectNodes('/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/*/DMSRule/RuleNumber/@Value') | Select-Object -ExpandProperty Value | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
    return $ruleId
}

function Format-SubstitutionRule {
    Param(
        [int]$RuleNumber,
        [string]$SerializedParentRuleId,
        [string]$Table,
        [string]$Description
    )

    [xml]$ruleXml = '
        <RuleSubstitution NS="DMS_Common" AS="DMSO">
            <DMSRule>
                <RuleBlock Value="01" />
                <RuleNumber Value="SUBSTITUTE" />
                <RuleSubscript Value="-01" />
                <IsDisabled Value="False" />
                <IsBulk Value="False" />
                <WantMultipleActiveResultSets Value="False" />
                <IsManagedRule Value="False" />
                <CommitFreq Value="1000" />
                <SerializedParentRuleID Value="SUBSTITUTE" />
                <Description Value="SUBSTITUTE" />
                <ExpandedState Value="False" />
                <ForceIsNullsOff Value="False" />
                <UserSpecifiedRIDIndexEnabled Value="False" />
                <UserSpecifiedRIDIndex Value="" />
            </DMSRule>
            <TargetTableName Value="SUBSTITUTE" />
                <WhereClauseAndSamplingContainer>
                    <WhereClause Value="where ..." />
                    <WhereClauseMode Value="Where_NotNullOrEmpty" />
                    <WantSamplePercent Value="False" />
                    <SamplePercentage Value="100.00" />
                    <WantRowLimit Value="False" />
                    <RowLimit Value="1000" />
                    <WantDistinctSet Value="False" />
                    <ForceInLineNullSkips Value="False" />
                </WhereClauseAndSamplingContainer>
                <RangeOptionsContainer>
                    <RangeClause Value="" />
                    <RangeLow Value="" />
                    <RangeHigh Value="" />
                </RangeOptionsContainer>
            <DMSPickedColumnAndDataSetCollection />
        </RuleSubstitution>'

    #update some rule properties with given values
    $ruleXml.SelectSingleNode('RuleSubstitution/DMSRule/RuleNumber/@Value').Value = ([string]$ruleNumber).PadLeft(4, '0')
    $ruleXml.SelectSingleNode('RuleSubstitution/DMSRule/SerializedParentRuleID/@Value').Value = $SerializedParentRuleId
    $ruleXml.SelectSingleNode('RuleSubstitution/DMSRule/Description/@Value').Value = $Description
    $ruleXml.SelectSingleNode('RuleSubstitution/TargetTableName/@Value').Value = $Table

    return $ruleXml
}

function Format-ColumnInfo {
    Param(
        [xml]$MaskingSet,
        [string]$Schema,
        [string]$Table,
        [string]$Column
    )

    [xml]$columnXml = '
        <DMSPickedColumnAndDataSet>
            <N2KSQLServerEntity_PickedColumn>
                <N2KSQLServerEntity />
                <ColumnName Value="SUBSTITUTE" />
                <ColumnConversionWrapper Value="" />
                <ColumnConversionEnabled Value="False" />
                <OrdinalPosition Value="SUBSTITUTE" />
                <DataType Value="SUBSTITUTE" />
                <IsPseudoColumn Value="False" />
                <DisplayUndefinedTextIfDatatypeNotDefined Value="True" />
            </N2KSQLServerEntity_PickedColumn>
        </DMSPickedColumnAndDataSet>'

    $columnXml.SelectSingleNode('DMSPickedColumnAndDataSet/N2KSQLServerEntity_PickedColumn/ColumnName/@Value').Value = $Column

    #update a couple of properties by looking them up in the controller's schema snapshot
    $dataType = $maskingSet.SelectSingleNode("/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table[TableName/@Value = `"$Table`"]/N2KSQLServerCollection_Column/DMSSchemaEntity_Column/N2KSQLServerEntity_Column[ColumnName/@Value = `"$Column`"]/DataType/@Value").Value
    $columnXml.SelectSingleNode('DMSPickedColumnAndDataSet/N2KSQLServerEntity_PickedColumn/DataType/@Value').Value = $dataType
    $ordinalPosition = $maskingSet.SelectSingleNode("/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table[TableName/@Value = `"$Table`"]/N2KSQLServerCollection_Column/DMSSchemaEntity_Column/N2KSQLServerEntity_Column[ColumnName/@Value = `"$Column`"]/OrdinalPosition/@Value").Value
    $columnXml.SelectSingleNode('DMSPickedColumnAndDataSet/N2KSQLServerEntity_PickedColumn/OrdinalPosition/@Value').Value = $ordinalPosition

    #some data types need an extra property for their length, also looked up in the controller
    if ($dataType -in 'char', 'varchar', 'text', 'nchar', 'nvarchar', 'ntext') {
        $length = $ordinalPosition = $maskingSet.SelectSingleNode("/DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table[TableName/@Value = `"$Table`"]/N2KSQLServerCollection_Column/DMSSchemaEntity_Column/N2KSQLServerEntity_Column[ColumnName/@Value = `"$Column`"]/CharacterMaximumLength/@Value").Value
        $fullDataTypeElement = $columnXml.CreateNode("element", "ColumnFullDataType", "")
        $fullDataTypeElement.SetAttribute("Value", "$dataType($length)")
        [void]$columnXml.SelectSingleNode('DMSPickedColumnAndDataSet/N2KSQLServerEntity_PickedColumn').AppendChild($fullDataTypeElement)
    }

    return $columnXml
}

function Update-PlanInformation {
    Param(
        [xml] $MaskingSet,
        [string] $Schema,
        [string] $Table,
        [string] $Column,
        [string] $Sensitivity
    )

    if ($Sensitivity) {
        if ($Sensitivity -like '*confidential*') {
            $planType = 'WANTMASK_YES'
        }
        elseif ($Sensitivity -like '*public*') {
            $planType = 'WANTMASK_NO'
        }
        else {
            $planType = 'WANTMASK_UNKNOWN'
        }
        $MaskingSet.SelectSingleNode("DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table[TableName/@Value = `"$Table`"]/N2KSQLServerCollection_Column/DMSSchemaEntity_Column[N2KSQLServerEntity_Column/ColumnName/@Value = `"$Column`"]/PlanType/@Value").Value = $planType
        $MaskingSet.SelectSingleNode("DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleController/DMSSchemaEntity_Login/N2KSQLServerEntity_Login[SchemaName/@Value = `"$Schema`"]/SchemaTables/DMSSchemaEntity_Table/N2KSQLServerEntity_Table[TableName/@Value = `"$Table`"]/N2KSQLServerCollection_Column/DMSSchemaEntity_Column[N2KSQLServerEntity_Column/ColumnName/@Value = `"$Column`"]/PlanComments/@Value").Value = $Sensitivity
    }

    return $MaskingSet
}

$fragmentMap = @{'ForeName' = [xml]'
        <DataSet_MFNAME NS="DMS_DataSets" AS="DMSD">
            <UpperCaseText Value="False" />
            <UniqueValuesOnly Value="False" />
        </DataSet_MFNAME>';
    'LastName'              = [xml]'
        <DataSet_LNAMEL NS="DMS_DataSets" AS="DMSD">
            <UpperCaseText Value="False" />
            <UniqueValuesOnly Value="False" />
        </DataSet_LNAMEL>';
    'FullName'              = [xml]'
        <DataSet_NAMFLX NS="DMS_DataSets" AS="DMSD">
            <UpperCaseText Value="False" />
            <UniqueValuesOnly Value="False" />
        </DataSet_NAMFLX>';
    'EmailAddress'          = [xml]'
        <DataSet_EMADDR NS="DMS_DataSets" AS="DMSD">
            <UpperCase Value="False" />
        </DataSet_EMADDR>';
    'PhoneNumber'           = [xml]'
        <DataSet_UKTELE NS="DMS_DataSets" AS="DMSD">
            <InvalidChecksum Value="False" />
            <DigitsOnly Value="True" />
            <SpaceSeparation Value="False" />
            <NoAreaCode Value="False" />
        </DataSet_UKTELE>';
    'DateOfBirth'           = [xml]'
        <DataSet_RNDDAX NS="DMS_DataSets" AS="DMSD">
            <ForceTimesToZero Value="True" />
            <LowDate Value="19300101 00:00:00" />
            <HighDate Value="20190101 00:00:00" />
            <StorageFormat Value="yyyy-MM-dd" />
        </DataSet_RNDDAX>';
    'PostCode'              = [xml]'
        <DataSet_UKPCGN NS="DMS_DataSets" AS="DMSD">
            <RemoveSpaces Value="False" />
        </DataSet_UKPCGN>';
    'BankSortCode'          = [xml]'
        <DataSet_UKBKST NS="DMS_DataSets" AS="DMSD">
            <DigitsOnly Value="True" />
            <SpaceSeparation Value="False" />
            <DashSeparation Value="False" />
        </DataSet_UKBKST>';
    'BankNumber'            = [xml]'
        <DataSet_RNDALN NS="DMS_DataSets" AS="DMSD">
            <TemplateString Value="%n%n%n%n%n%n%n%n" />
        </DataSet_RNDALN>';
    'AddressLine'           = [xml]'
        <DataSet_STADDR NS="DMS_DataSets" AS="DMSD">
            <UpperCaseText Value="False" />
            <NeverAbbreviate Value="False" />
            <NamesOfStreetsOnly Value="True" />
            <DataSetFilename Value="random_street_addr.dmds" />
        </DataSet_STADDR>';
    'Sentence'              = [xml]'
        <DataSet_PARGIB NS="DMS_DataSets" AS="DMSD">
            <MinChars Value="1" />
            <MaxChars Value="200" />
            <MaxWordLen Value="20" />
        </DataSet_PARGIB>'
}

function Get-MaskingTaxonomyTags {
    return $fragmentMap.keys;
}

function Get-DataSet {
    Param(
        [string]$DataSetLabel
    )

    return $fragmentMap[$DataSetLabel]
}

#for debugging...
function Write-Xml {
    Param(
        [xml]$Xml
    )
    $stringWriter = New-Object -TypeName System.IO.StringWriter
    $xmlWriter = New-Object -TypeName System.Xml.XmlTextWriter -ArgumentList $stringWriter
    $Xml.WriteTo($xmlWriter)
    $output = $stringWriter.ToString()
    Write-Output $output
}

Export-ModuleMember -Function Get-HighestRuleId
Export-ModuleMember -Function Get-DataSet
Export-ModuleMember -Function Test-ControllerExists
Export-ModuleMember -Function Test-TableExists
Export-ModuleMember -Function Test-ColumnExists
Export-ModuleMember -Function Format-SubstitutionRule
Export-ModuleMember -Function Format-ColumnInfo
Export-ModuleMember -Function Format-ControllerSerializedId
Export-ModuleMember -Function Add-ColumnToSubstitutionRule
Export-ModuleMember -Function Add-RuleToMaskingSet
Export-ModuleMember -Function Update-PlanInformation
Export-ModuleMember -Function Write-Xml
Export-ModuleMember -Function Get-MaskingTaxonomyTags
