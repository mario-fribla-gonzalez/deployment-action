param(
    [string]$PackageName = "",
    [string]$PackageExtension = "",
    [string]$ReleaseVersion = "",
    [string]$DeploymentName = "",
    [string]$IISServerName = "",
    [string]$IISServerUser = "",
    [string]$IISServerKey = "",
    [string]$CarpetaSLN = "",
    [bool]$DeleteRelease = $false
)

$IISServerPort=8172
$Resultado = Test-NetConnection "$IISServerName" -Port "$IISServerPort" -InformationLevel "Quiet"
if ( $Resultado ) {
    Write-Host "$IISServerName is Enabled."
} else {
    Write-Host "$IISServerName is not Enabled."
    exit 0
}
    
$esc = [char]27
$greenf = "$esc[32m"
$reset = "$esc[0m"

# Set DeploymentName to PackageName if not provided
if ([string]::IsNullOrEmpty($DeploymentName)) {
    $DeploymentName = $PackageName
}
Write-Host "${greenf}Starting deployment for $PackageName to $DeploymentName on $IISServerName${reset}"

if ($env:RUNNER_DEBUG -eq "1") {
    Set-PSDebug -Trace 1
}
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$IISServerKey = $IISServerKey -replace "'", "''"

# Compose artifact name
$VersionedArtifact = "$PackageName-$ReleaseVersion.$PackageExtension"
if ($ReleaseVersion -and (Test-Path $VersionedArtifact)) {
    $ArtifactName = $VersionedArtifact
} else {
    $ArtifactName = "$PackageName.$PackageExtension"
}

# Define msdeploy endpoint URL
$MsDeployUrl = "https://$IISServerName.domainuap.cl:8172/msdeploy.axd?site=$DeploymentName"
Write-Host "${greenf}Deploying to: $MsDeployUrl${reset}"

$commonDestArgs = "ComputerName=$MsDeployUrl,userName=`"$IISServerUser`",password=`"$IISServerKey`",authType=basic"

# Helper to run msdeploy with common arguments
function Invoke-MsDeploy {
    param (
        [string[]]$Arguments
    )
    # Insert allowUntrusted after the verb if not already present
    $allowUntrusted = if ($env:IIS_ALLOW_INSECURE -eq "true") { "-allowUntrusted" } else { "" }
    if ($allowUntrusted -ne "" -and $Arguments.Count -gt 1 -and $Arguments[1] -ne $allowUntrusted) {
        $Arguments = @($Arguments[0], $allowUntrusted) + $Arguments[1..($Arguments.Count - 1)]
    }
    Write-Host "${greenf}msdeploy command: msdeploy $($Arguments -join ' ')${reset}"
    $result = & msdeploy @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Error "::error::msdeploy failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    return $result
}

if (-not (Test-Path $ArtifactName)) {
    Write-Error "::error::Artifact not found: $ArtifactName"
    exit 1
}

# Stop App Pool
Write-Host "${greenf}Stopping App Pool for $DeploymentName${reset}"
Invoke-MsDeploy -Arguments @(
    "-verb:sync"
    "-source:recycleApp"
    "-dest:recycleApp=$DeploymentName,recycleMode=StopAppPool,$commonDestArgs"
)
Start-Sleep -Seconds 5

# Optional: Clean server
if ($DeleteRelease) {
    $emptyDir = "D:\empty"
    New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null
    Write-Host "${greenf}Cleaning server directory for $DeploymentName${reset}"
    try {
        Invoke-MsDeploy -Arguments @(
            "-verb:sync"
            "-source:contentPath=$emptyDir"
            "-dest:contentPath=$DeploymentName,$commonDestArgs"
        )
    } catch {
        Write-Warning "::warning:: Cleaning step failed (possibly because the app does not exist). Continuing..."
    }
}

# List only site names
Write-Host "${greenf}Listing IIS site names on $IISServerName${reset}"
Invoke-MsDeploy -Arguments @(
    "-verb:dump"
    "-source:iisApp=$DeploymentName,$commonDestArgs"
)

# Unzip the package into a "release" folder before deployment
$releaseDir = "release"
if (Test-Path $releaseDir) {
    Remove-Item -Recurse -Force $releaseDir
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null

if ($ArtifactName.ToLower().EndsWith(".zip")) {
    Write-Host "${greenf}Extracting $ArtifactName to $releaseDir${reset}"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ArtifactName, $releaseDir)
} else {
    Write-Host "${greenf}Package is not a ZIP file, skipping extraction.${reset}"
}

Get-ChildItem -Force

# Publish
Write-Host "${greenf}Starting Publish for $DeploymentName${reset}"
Invoke-MsDeploy -Arguments @(
    "-verb:sync"
    "-source:iisApp=$(Join-Path (Get-Location) 'release')"
    "-dest:iisApp=$DeploymentName,$commonDestArgs"
    "-enableRule:DoNotDelete"
)

# Start App Pool
Write-Host "${greenf}Starting App Pool for $DeploymentName${reset}"
Invoke-MsDeploy -Arguments @(
    "-verb:sync"
    "-source:recycleApp"
    "-dest:recycleApp=$DeploymentName,recycleMode=StartAppPool,$commonDestArgs"
)
