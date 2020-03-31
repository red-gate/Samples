
#$Script:session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

function Connect-Collibra {
    param (
        [Parameter(Mandatory)][string] $collibraAPI,        
        [Parameter(Mandatory)][string] $userName,        
        [Parameter(Mandatory)][string] $password
    )
    $uri = "$collibraAPI/auth/sessions"
    $body = [PSCustomObject]@{
        username = $userName;
        password = $password
    } | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -ContentType 'application/json' -SessionVariable 'Session'
    
    $Script:session = $Session
}

function Import-CollibraDatabase {
    param (
        [Parameter(Mandatory)][string] $collibraAPI,
        [Parameter(Mandatory)][string] $synchronizationId,        
        [Parameter(Mandatory)][object] $json
    )
    $Uri = "$collibraAPI/import/json-job"
    $json | ConvertTo-Json -Depth 10 | Out-File '.\export.json'
    $Form = @{
        fileName     = 'import_file'
        file         = Get-Item -Path  '.\export.json'
    }
    $Result = Invoke-RestMethod -Uri $Uri -Method Post -Form $Form -WebSession $Script:session -ContentType 'multipart/form-data'
}

function Disconnect-Collibra {
    param (
        [Parameter(Mandatory)][string] $collibraAPI
    )
    $uri = "$collibraAPI/auth/sessions/current"
    Invoke-RestMethod -Uri $uri -Method "Delete" -WebSession $Script:session
    $Script:session = $null
}

