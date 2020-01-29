##########################################################################################
# clone-branch.ps1 version 0.1
##########################################################################################

##########################################################################################
# Configuration
##########################################################################################
$CloneServerUrl = "https://<clone-server-url>:14145"
$ImageName = "<image-name>"                 # SQL Clone image from which dev database clones will be created
$SqlServerMachineName = "<machine-name>"    # SQL Server machine hosting the clone database (must have Clone Agent installed):
$SqlServerInstanceName = "<instance-name>"  # Use empty string for the default instance
$DBName = "<clone-name>"                    # Database name linked to project (could pull this from project file XML if required) 
##########################################################################################

$ErrorActionPreference = "Stop"

# This script currently assumes Windows Auth will be used to connect to the database clone

# We start a timer so we can measure how long the provision takes
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

# Find the branch name we've switched to, which we use to label per-branch Clones
if ($null -ne (Get-Command "git" -ErrorAction SilentlyContinue)) {
    $reflogResult = git reflog
    $lastReflog = $reflogResult[0]
    $lastReflogTokens = $lastReflog.Split(" ")
    $fromBranchName = $lastReflogTokens[5]
    $toBranchName = $lastReflogTokens[7]
    $fromBranch = "$($fromBranchName | ForEach-Object {$_ -replace "\W"})"
    $toBranch = "$($toBranchName | ForEach-Object {$_ -replace "\W"})"
    Write-Host "We have switched from branch ${fromBranch} to branch ${toBranch}"
}
else
{
    Write-Host "git could not be found, so from-branch and to-branch could not be determined"
    Write-Host "This may go very badly, perhaps we should have terminated"
}

# We will use the username and branch name to uniquify name the clones
$username = $env:UserName

# Connect to Clone Server and obtain resources
Connect-SqlClone $CloneServerUrl -ErrorAction Stop

$image = Get-SqlCloneImage $ImageName -ErrorAction Stop
Write-Host "Successfully found SQL Clone image $ImageName at $CloneServerUrl"

$sqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $SqlServerMachineName -InstanceName $SqlServerInstanceName -ErrorAction Stop
Write-Host "Found SQL Server instance ${SqlServerMachineName}\${SqlServerInstanceName}"

function TrySaveBranchClone {
    param ($branchnamevalue)
    Write-Host "Rename $DBName with the branch and username so we can retrieve it later: ${DBName}_${branchnamevalue}_${username}"

    $renameMe = Get-SqlClone -Name $DBName

    try {
        $renameOperation = Rename-SqlClone -Clone $renameMe -NewName  ${DBName}_${branchnamevalue}_${username}
        Wait-SqlCloneOperation -Operation $renameOperation
        return $true
    }
    catch {
        # This could mask other errors - we are only considering renaming on switching to same branch
        Write-Host "Skipped: The rename could not be completed, a checkout to the same branch may have occurred."
        return $false
    }
}

function CreateClone {
    Write-Host "We create a new clone: ${DBName} and migrate the new clone to the version represented in the branch"   
    New-SqlClone -Name ${DBName} -Image $image -Location $sqlServerInstance -ErrorAction Stop | Wait-SqlCloneOperation -ErrorAction Stop
}

# We create a new clone in the case we can't find a linked database clone, eg first time setup. 
if ($null -eq (Get-SqlClone -Name $DBName -Location $sqlServerInstance -ErrorAction SilentlyContinue)) {
    # Clone for current branch doesn't exist
    Write-Host "Need to create a Clone $DBName as it doesn't exist already."
    CreateClone
}

# We've switched branch so need to see if there's a clone already for this branch we can switch to
$targetCloneName = "${DBName}_${toBranch}_${username}" # This is the clone name we're expecting
Write-Host "Checking existence in SQL Clone for: $targetCloneName"

if ($null -ne (Get-SqlClone -Name $targetCloneName -Location $sqlServerInstance -ErrorAction SilentlyContinue)) {
    # Confirmed that Clone for branch exists so we save off the existing database
    
    if(-not (TrySaveBranchClone  $fromBranch))
    {
        return
    }

    Write-Host "As $targetCloneName has been found, we rename this to be the linked dev database: $DBName"
    $renameMe = Get-SqlClone $targetCloneName

    $renameOperation = Rename-SqlClone -Clone $renameMe -NewName $DBName
    Wait-SqlCloneOperation -Operation $renameOperation -ErrorAction Ignore
}
else {
    # Per-branch Clone doesn't exist so we create a new one after save the current clone, naming it with the branch and user
    Write-Host "Saved Clone $targetCloneName not found. Save current $fromBranch clone and create a new one."
    if(-not (TrySaveBranchClone  $fromBranch))
    {
        return
    }
    CreateClone
}

# Stop the stopwatch
$StopWatch.Stop()
$provisionTime = $StopWatch.Elapsed.ToString('ss')
Write-Host "Provisioned a database clone for branch ${toBranch}" -ForegroundColor Green
if ($toBranch -ne $fromBranch) { Write-Host "(and saved off a clone for branch ${fromBranch} so we can switch back to it later)" -ForegroundColor Green }
Write-Host "SCA Provision time: ${provisionTime} seconds" -ForegroundColor Green