
function Convert-CollibraJSON {
    param (
        $communityName = "SqlDataCatalog_ImportedDatabase_11234",
        [Parameter(Mandatory)][string] $instanceName,
        [Parameter(Mandatory)][string] $databaseName,
        [object[]] $columns
    )

    $export = @()

    # Constants

    $personallyIdentifiableInformationTags = @(
        "Confidential_-_GDPR",
        "Highly_Confidential_-_GDPR"
    )

    $securityClassificationMappings = @{
        "Confidential" = "Confidential";
        "Confidential_-_GDPR" = "Confidential";
        "Highly_Confidential" = "Highly Confidential";
        "Highly_Confidential_-_GDPR" = "Highly Confidential";
        "General" = "Internal Only";
        "Public" = "Public";
    }


    # Community

    $communityIdentifier = [pscustomobject]@{
        name = $communityName
    }

    $export += [pscustomobject]@{
        resourceType = "Community";
        identifier   = $communityIdentifier;
        name         = $communityName
    }
    # Domains

    $systemsAndDatabasesIdentifier = [pscustomobject]@{
        name      = "Systems & Databases";
        community = $communityIdentifier
    }

    $physicalModelIdentifier = [pscustomobject]@{
        name      = "Physical Model";
        community = $communityIdentifier
    }

    $export += [pscustomobject]@{
        resourceType = "Domain";
        identifier   = $systemsAndDatabasesIdentifier;
        type         = [pscustomobject]@{
            name = "Technology Asset Domain"
        }
    }

    $export += [pscustomobject]@{
        resourceType = "Domain";
        identifier   = $physicalModelIdentifier;
        type         = [pscustomobject]@{
            name = "Physical Data Dictionary"
        }
    }

    # Instance and database

    $acceptedStatus = [pscustomobject]@{
        name = "Accepted"
    }
    $instanceIdentifier = [pscustomobject]@{
        name   = $instanceName;
        domain = $systemsAndDatabasesIdentifier
    }
    $export += [pscustomobject]@{
        resourceType = "Asset";
        identifier   = $instanceIdentifier;
        displayName  = $instanceName;
        type         = [pscustomobject]@{
            name = "Server"
        };
        status       = $acceptedStatus;
    }

    $databaseIdentifier = [pscustomobject]@{
        name   = "$instanceName>$databaseName";
        domain = $systemsAndDatabasesIdentifier
    };
    $export += [pscustomobject]@{
        resourceType = "Asset";
        identifier   = $databaseIdentifier;
        displayName  = $databaseName;
        type         = [pscustomobject]@{
            name = "Database"
        };
        status       = $acceptedStatus;
        relations    = [pscustomobject]@{
            "00000000-0000-0000-0000-000000007054:SOURCE" = @($instanceIdentifier)
        }
    }

    $columns | Group-Object schemaName | ForEach-Object {


        # schema

        $schemaName = $_.Name
        $schemaIdentifier = [pscustomobject]@{
            name   = "$instanceName>$databaseName>$schemaName";
            domain = $physicalModelIdentifier
        };

        $export += [pscustomobject]@{
            resourceType = "Asset";
            identifier   = $schemaIdentifier
            displayName  = $schemaName;
            type         = [pscustomobject]@{
                name = "Schema"
            };
            status       = $acceptedStatus;
            relations    = [pscustomobject]@{
                "00000000-0000-0000-0000-000000007005:TARGET" = @($databaseIdentifier)
            }
        }

        $_.group | Group-Object tableName | ForEach-Object {
            # table

            $tableName = $_.Name
            $tableIdentifier = [pscustomobject]@{
                name   = "$instanceName>$databaseName>$schemaName>$tableName";
                domain = $physicalModelIdentifier
            };
            $export += [pscustomobject]@{
                resourceType = "Asset";
                identifier   = $tableIdentifier;
                displayName  = $tableName;
                type         = [pscustomobject]@{
                    name = "Table"
                };
                status       = $acceptedStatus;
                relations    = [pscustomobject]@{
                    "00000000-0000-0000-0000-000000007043:SOURCE" = @($schemaIdentifier)
                }
            }

            $_.group | ForEach-Object {
                # column

                $columnName = $_.columnName
                $tagNames = @()
                Foreach ($tag in $_.tags) {
                    $tagNames += ($tag.name.Replace(" ", "_"))
                }
                $columnIdentifier = [pscustomobject]@{
                    name   = "$instanceName>$databaseName>$schemaName>$tableName>$columnName";
                    domain = $physicalModelIdentifier
                };

                # Attributes
                $attributes = [pscustomobject]@{}

                $securityClassificationTag = $tagNames.Where({ $securityClassificationMappings.ContainsKey($_) }, 'First')
                if($securityClassificationTag) {
                    $attributes | Add-Member -MemberType NoteProperty -Name "Security Classification" -Value @(
                        [pscustomobject]@{
                            value = $securityClassificationMappings[$securityClassificationTag][0]
                        }
                    )
                }

                $isPii = ($personallyIdentifiableInformationTags.Where({ $tagNames.Contains($_) }, 'First').Count -gt 0)
                $attributes | Add-Member -MemberType NoteProperty -Name "Personally Identifiable Information" -Value  @(
                    [pscustomobject]@{
                        value = $isPii
                    }
                )

                $export += [pscustomobject]@{
                    resourceType = "Asset";
                    identifier   = $columnIdentifier;
                    displayName  = $columnName;
                    type         = [pscustomobject]@{
                        name = "Column"
                    };
                    status       = $acceptedStatus;
                    relations    = [pscustomobject]@{
                        "00000000-0000-0000-0000-000000007042:TARGET" = @($tableIdentifier)
                    };
                    tags         = $tagNames;
                    attributes   = $attributes
                }

            }

        }

    }

    return $export
}
