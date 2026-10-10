param(
    [ValidateSet('both', 'web', 'windows')]
    [string]$Frontend = 'both'
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$flutterRoot = Join-Path $projectRoot 'flutter'
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterPath = $flutterCommand.Source
$fileSystem = New-Object -ComObject Scripting.FileSystemObject
$shortFlutterPath = $fileSystem.GetFile($flutterPath).ShortPath
if (Test-Path $shortFlutterPath) {
    $flutterPath = $shortFlutterPath
}

docker compose --project-directory $projectRoot up -d app
if ($LASTEXITCODE -ne 0) {
    throw 'Could not start the SearchTeach backend with Docker Compose.'
}

if ($Frontend -in @('both', 'web')) {
    Start-Process -FilePath $flutterPath `
        -ArgumentList @('run', '-d', 'chrome', '--web-port', '5001') `
        -WorkingDirectory $flutterRoot
}

if ($Frontend -in @('both', 'windows')) {
    Start-Process -FilePath $flutterPath `
        -ArgumentList @('run', '-d', 'windows') `
        -WorkingDirectory $flutterRoot
}

Write-Host 'Flutter launchers started. Web: http://localhost:5001; API: http://localhost:8080.'
