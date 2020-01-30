##########################################################################################
############################## clone-branch.ps1 version 0.2 ##############################
##########################################################################################

##################################### Configuration ######################################

#$VerbosePreference = "Continue"            # Uncomment this line to enable verbose logging
$InformationPreference = "Continue"         # Comment this line to disable information logging
$ErrorActionPreference = "Stop"

$CloneServerUrl = "https://<clone-server-url>:14145"
$ImageName = "<image-name>"                 # SQL Clone image from which dev database clones will be created
$SqlServerMachineName = "<machine-name>"    # SQL Server machine hosting the clone database (must have Clone Agent installed):
$SqlServerInstanceName = "<instance-name>"  # Use empty string for the default instance
$DBName = "<clone-name>"                    # Database name linked to project

##########################################################################################

function GetFromAndToBranchNames {
    $reflogResult = git reflog
    $lastReflog = $reflogResult[0]
    $lastReflogTokens = $lastReflog.Split(" ")
    $fromBranchName = $lastReflogTokens[5]
    $toBranchName = $lastReflogTokens[7]
    $fromBranch = "$($fromBranchName | ForEach-Object {$_ -replace "\W"})"
    $toBranch = "$($toBranchName | ForEach-Object {$_ -replace "\W"})"

    $fromBranch
    $toBranch
}

function GetCloneBranchName {
    param ($branchNameValue)
    return "${DBName}_${branchNameValue}_${env:UserName}"
}

function CloneExists {
    param ($cloneName)
    return $null -ne (Get-SqlClone -Name $cloneName -Location $sqlServerInstance -ErrorAction SilentlyContinue)
}

function CreateClone {
    Write-Verbose "Provisioning database ${DBName}..."
    New-SqlClone -Name ${DBName} -Image $image -Location $sqlServerInstance -ErrorAction Stop | Wait-SqlCloneOperation -ErrorAction Stop
}

function RenameClone {
    param ($fromName, $toName)

    Write-Verbose "Renaming $fromName to $toName..."
    $renameMe = Get-SqlClone $fromName -ErrorAction Stop

    $renameOperation = Rename-SqlClone -Clone $renameMe -NewName $toName
    Wait-SqlCloneOperation -Operation $renameOperation -ErrorAction Stop
}

function ProvisionCloneForBranch {
    $fromCloneBranchName = GetCloneBranchName $fromBranch # This is what we will rename the current clone to, if present
    $toCloneBranchName = GetCloneBranchName $toBranch # This is the clone name we're expecting

    # We create a new clone in the case we can't find a linked database clone, eg first time setup.
    if (CloneExists $DBName) {
        # Clone for current branch doesn't exist
        RenameClone $DBName $fromCloneBranchName
    }

    # We've switched branch so need to see if there's a clone already for this branch we can switch to
    if (CloneExists $toCloneBranchName) {
        # Confirmed that clone for branch exists so we save off the existing database
        RenameClone $toCloneBranchName $DBName
    }
    else {
        # Per-branch clone doesn't exist so we create a new one after save the current clone, naming it with the branch and user
        CreateClone
    }
}

##########################################################################################

if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue)) {
    throw "This script requires git to be installed and available on PATH"
}

$branchNames = GetFromAndToBranchNames
$fromBranch = $branchNames[0]
$toBranch = $branchNames[1]

if ($fromBranch -eq $toBranch) {
    return
}

Write-Information "Provisioning database ${DBName} for branch ${toBranch}..."
Write-Verbose "Switched from branch ${fromBranch} to branch ${toBranch}"

$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

Connect-SqlClone $CloneServerUrl -ErrorAction Stop

$image = Get-SqlCloneImage $ImageName -ErrorAction Stop
Write-Verbose "Found SQL Clone image $ImageName at $CloneServerUrl"

$sqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $SqlServerMachineName -InstanceName $SqlServerInstanceName -ErrorAction Stop
Write-Verbose "Found SQL Server instance ${SqlServerMachineName}\${SqlServerInstanceName}"

ProvisionCloneForBranch

$StopWatch.Stop()
$provisionTime = $StopWatch.Elapsed.ToString('ss')
Write-Information "Database ${DBName} successfully provisioned by SQL Clone (took ${provisionTime} seconds)"
