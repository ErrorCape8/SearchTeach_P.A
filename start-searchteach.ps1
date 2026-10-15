param(
    [ValidateSet('both', 'web', 'windows')]
    [string]$Frontend = 'both'
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$flutterRoot = Join-Path $projectRoot 'flutter'
if (-not (Test-Path $flutterRoot -PathType Container)) {
    throw "No se encontró la carpeta Flutter: $flutterRoot"
}

$script:reservedFlutterDrives = @()
if ($Frontend -in @('both', 'windows')) {
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $flutterPath = $flutterCommand.Source
    $flutterSdkRoot = Split-Path (Split-Path $flutterPath -Parent) -Parent
}

function Start-FlutterSession {
    param([Parameter(Mandatory = $true)][string]$Arguments)

    $flutterDrive = @('Z', 'Y', 'X', 'W', 'V', 'U', 'T', 'S', 'R', 'Q', 'P', 'O', 'N', 'M', 'L', 'K', 'J', 'I', 'H', 'G', 'F', 'E', 'D') |
        Where-Object {
            $candidate = $_
            $candidate -notin $script:reservedFlutterDrives -and
                -not (Get-PSDrive -Name $candidate -ErrorAction SilentlyContinue)
        } |
        Select-Object -First 1
    if (-not $flutterDrive) {
        throw 'No hay una letra de unidad disponible para iniciar Flutter sin espacios en la ruta.'
    }
    $script:reservedFlutterDrives += $flutterDrive

    $driveRoot = "${flutterDrive}:"
    $flutterAliasPath = "${driveRoot}\bin\flutter.bat"
    $quotedSdkRoot = $flutterSdkRoot.Replace("'", "''")
    $commandText = "& subst.exe '$driveRoot' '$quotedSdkRoot'; if (`$LASTEXITCODE -ne 0) { Write-Host 'No se pudo preparar la ruta de Flutter.'; Read-Host 'Presiona Enter para cerrar esta ventana'; exit 1 }; & '$flutterAliasPath' $Arguments; `$flutterExitCode = `$LASTEXITCODE; & subst.exe '$driveRoot' /d; if (`$flutterExitCode -ne 0) { Write-Host ''; Write-Host ('Flutter terminó con código {0}.' -f `$flutterExitCode); Read-Host 'Presiona Enter para cerrar esta ventana' }"
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))

    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedCommand) `
        -WorkingDirectory $flutterRoot `
        -PassThru | Out-Null
}

if ($Frontend -in @('both', 'web')) {
    docker compose --project-directory $projectRoot up -d --build app frontend
} else {
    docker compose --project-directory $projectRoot up -d --build app
}
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo iniciar Docker Compose. Revisa Docker Desktop y el mensaje de Compose.'
}

if ($Frontend -in @('both', 'web')) {
    Start-Process 'http://localhost:5001'
}

if ($Frontend -in @('both', 'windows')) {
    Start-FlutterSession 'run -d windows --dart-define=API_BASE_URL=http://localhost:8081'
}

Write-Host 'SearchTeach listo. Web: http://localhost:5001; API: http://localhost:8081.'