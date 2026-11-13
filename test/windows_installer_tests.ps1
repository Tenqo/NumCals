$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$installerScript = Join-Path $projectRoot 'tooling\windows\Install-LatestRelease.ps1'

& $installerScript -SelfTest
if (-not $?) {
    throw 'Windows installer self-tests failed.'
}
