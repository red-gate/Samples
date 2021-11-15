# Based on the structure of AdventureWorks (see `Classify Adventureworks database`)
# Presumes that you have the foundational information types and information classification tags

$authToken = "OTA5ODE2NDgzOTg1NDg5OTIwOjI5MzM3NjQyLWQwZDItNGZiZS1iOGY5LTc0ZDMyYjUyZDcwMQ=="
$serverUrl = "http://localhost:15156" # or https:// if you've configured SSL

$headers = @{
    'Authorization' = "Bearer $authToken"
    'Cache-Control' = 'no-cache'
}

$body = @{
    name     = "ZZ. Descope system columns"
    tagIds   = @(491288012315960037, 491288012315962001)
    filters = @(
        {
            primaryKeyFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            foreignKeyFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            compositeKeyFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            identityConstraintFilter = "Require",
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("int", "bigint", "tinyint", "smallint", "uniqueidentifier")
        },
        {
            taggedColumnsFilter = "Exclude",
            columnDataTypeFullNames = @("bit", "uniqueidentifier")
        }
    )
}

Invoke-RestMethod -Uri "$serverUrl/api/v1.0/suggestion-rules" -Method Post -Body ($body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8' -UseBasicParsing -Headers $headers
