
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
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -SessionVariable 'Session'

    $Script:session = $Session
    $Script:collibaUri = $collibraAPI
}

function Import-CollibraDatabase {
    param (
        [Parameter(Mandatory)][string] $synchronizationId,
        [Parameter(Mandatory)][object] $json
    )
    $Uri = "$Script:collibaUri/import/synchronize/$synchronizationId/json-job"
    $json | ConvertTo-Json -Depth 10 | Out-File '.\export.json'
    $Form = @{
        fileName = 'import_file'
        file     = Get-Item -Path  '.\export.json'
    }
    Invoke-RestMethod -Uri $Uri -Method Post -Form $Form -WebSession $Script:session -ContentType 'multipart/form-data'
}

function Import-BatchCollibraDatabase {
    param (
        [Parameter(Mandatory)][string] $synchronizationId,
        [Parameter(Mandatory, ValueFromPipeLine)][object] $json
    )
    $Uri = "$Script:collibaUri/import/synchronize/$synchronizationId/batch/json-job"
    $json | ConvertTo-Json -Depth 10 | Out-File '.\export.json'
    $Form = @{
        fileName = 'import_file'
        file     = Get-Item -Path  '.\export.json'
    }
    $response = Invoke-RestMethod -Uri $Uri -Method Post -Form $Form -WebSession $Script:session -ContentType 'multipart/form-data'
    Wait-Operation -jobId $response.id
}

function Wait-Operation {
    param (
        [Parameter(Mandatory)][string] $jobId
    )
    $TimeEnd = (Get-Date).AddSeconds(60)

    Do {
        Start-Sleep -Seconds 1
        $completedStates = @( "CANCELING", "COMPLETED", "CANCELED", "ERROR")

        #https://redgate.collibra.com/rest/2.0/jobs/86e42720-23f6-462e-941d-486416e025d9
        $Uri = "$Script:collibaUri/jobs/$jobId"
        $result = Invoke-RestMethod -Uri $Uri -Method Get -WebSession $Script:session -ContentType 'application/json'

        if ($result.state -in $completedStates ) {
            return
        }
    }
    Until ((Get-Date) -ge $TimeEnd)
}

function Complete-CollibraSync {
    param (
        [Parameter(Mandatory)][string] $synchronizationId
    )
    $Uri = "$Script:collibaUri/import/synchronize/$synchronizationId/finalize/job"
    $Form = @{
    }
    Invoke-RestMethod -Uri $uri -Method Post -Form $Form -WebSession $Script:session -ContentType 'multipart/form-data'
}

function Disconnect-Collibra {
    $uri = "$Script:collibaUri/auth/sessions/current"
    Invoke-RestMethod -Uri $uri -Method Delete -WebSession $Script:session
    $Script:session = $null
}
