param(
    [string]$PackageName = "",
    [string]$PackageExtension = "",
    [string]$ReleaseVersion = "",
    [string]$TypescriptNombreSitio = "",
    [string]$CarpetaPath = "",
    [string]$CRMEnvironment = ""
)

function Install-AngularCLI {
    $cliVersion = node -p "require('./package.json').devDependencies['@angular/cli'] || require('./package.json').dependencies['@angular/cli']"
    Write-Host "Installing @angular/cli version: $cliVersion"
    if ($cliVersion) {
        npm install -g "@angular/cli@$cliVersion"
    } else {
        Write-Host "::error::@angular/cli not found in package.json"
        exit 1
    }
}

function Build-Dist {
    Write-Host "Installing dependencies and buils directory Dist for Node.js application"
    npm install --save-dev @vercel/ncc
    npm run build
}

Get-ChildItem -Force

if ( $CRMEnvironment -ne "development" ) {
    $ArtifactName = "$PackageName-$ReleaseVersion.$PackageExtension"
} else {
    $ArtifactName = "$PackageName.$PackageExtension"
}

if (-not (Test-Path $ArtifactName)) {
    Write-Host "::error::Artifact not found: $ArtifactName"
    exit 1
}
Write-Host "Desplegando typescript application: $ArtifactName"
if ($PackageExtension -eq "zip") {
    Expand-Archive -Path "$ArtifactName" -DestinationPath . -Force
} elseif ($PackageExtension -eq "tar.gz") {
    tar -xzf $ArtifactName
} else {
    Write-Host "::error::Unsupported package extension: $PackageExtension"
    exit 1
}
Get-ChildItem -Force

# Ejecuta Instlación CLiente Angular, Dependencias y Construye directorio Dist/ para Apliaciaones Angular SI ES DEVELOPER o QA.
if ( $CRMEnvironment -eq "development" ) {
   Install-AngularCLI
   Build-Dist
   $DirOrigen="dist\\*"
} else { # SINO es Produccion
   $DirOrigen="*"
}

$DirDestino="$CarpetaPath\\$TypescriptNombreSitio"
Write-Host "Creando Directorio Temporal $TypescriptNombreSitio"
if (Test-Path -Path $DirDestino ) {
    Write-Host "El directorio existe $TypescriptNombreSitio"
} else {
    Write-Host "El directorio no existe."
    New-Item -ItemType Directory -Path $DirDestino
}

Write-Host "Change Directory: $DirOrigen"
Set-Location "$DirOrigen"

Write-Host "Copy typescript application: $TypescriptNombreSitio"
xcopy /E /Y /Q * "$DirDestino"

$ArchivoControl="$CarpetaPath\\$TypescriptNombreSitio.dpy"
"1" | Out-File -FilePath $ArchivoControl
Write-Host "Archivo de Control Creado en: $ArchivoControl"

exit 0
