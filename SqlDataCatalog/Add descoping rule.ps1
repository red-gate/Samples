# Based on the structure of AdventureWorks (see `Classify Adventureworks database`)
# Presumes that you have the foundational information types and information classification tags

$authToken = "[Your auth token]"
$serverUrl = "http://[Your SQL Data Catalog Server FQDN]:15156" # or https:// if you've configured SSL

$headers = @{
    'Authorization' = "Bearer $authToken"
    'Cache-Control' = 'no-cache'
}

$body = @{
    name     = "ZZ. Descope system columns"
    tagIds   = @(491288012315960037, 491288012315962001)
    filters = @(
        @{
            primaryKeyFilter = "Require"
            taggedColumnsFilter = "Exclude"
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        @{
            foreignKeyFilter = "Require"
            taggedColumnsFilter = "Exclude"
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        @{
            compositeKeyFilter = "Require"
            taggedColumnsFilter = "Exclude"
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        @{
            identityConstraintFilter = "Require"
            taggedColumnsFilter = "Exclude"
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        @{
            taggedColumnsFilter = "Exclude"
            columnDataTypeFullNames = @("bit", "uniqueidentifier")
        },
        @{
            columnNameSubstring = @("%modifieddate", "%modifydate", "timestamp", "%date%modified")
        }
    )
}

$bodyJson = @($body) | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "$serverUrl/api/v1.0/suggestion-rules" -Method Post -Body $bodyJson -ContentType 'application/json; charset=utf-8' -UseBasicParsing -Headers $headers
