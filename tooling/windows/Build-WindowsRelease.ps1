$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releasePath = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$outputPath = Join-Path $projectRoot 'dist'
$portablePath = Join-Path $outputPath 'FlCalculator-portable.zip'
$installerScript = Join-Path $projectRoot 'packaging\windows\FlCalculator-Setup.iss'
$releaseInstallScript = Join-Path $PSScriptRoot 'Install-LatestRelease.ps1'

Push-Location $projectRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed.'
    }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows release build failed.'
    }

    if (-not (Test-Path -LiteralPath (Join-Path $releasePath 'flcalculator.exe'))) {
        throw "The Windows app was not found at $releasePath."
    }

    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    Compress-Archive -Path (Join-Path $releasePath '*') -DestinationPath $portablePath -Force

    $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($null -eq $compilerCommand) {
        $innoSetupPaths = @(
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
        )
        $compilerPath = $innoSetupPaths | Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
    } else {
        $compilerPath = $compilerCommand.Source
    }

    if (-not $compilerPath) {
        throw 'Inno Setup 6 is required to create the setup wizard. Install it on the build machine or use the GitHub release workflow.'
    }

    $versionMatch = Select-String -Path (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*(\d+\.\d+\.\d+)'
    if ($null -eq $versionMatch) {
        throw 'Could not read the app version from pubspec.yaml.'
    }

    $compilerArguments = @(
        "/DAppSource=$releasePath",
        "/DAppVersion=$($versionMatch.Matches[0].Groups[1].Value)",
        "/O$outputPath",
        '/FFlCalculator-Setup',
        $installerScript
    )
    & $compilerPath @compilerArguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $outputPath 'FlCalculator-Setup.exe') -PathType Leaf)) {
        throw 'Inno Setup could not create the Windows setup executable.'
    }

    Copy-Item -LiteralPath $releaseInstallScript -Destination $outputPath -Force

    Write-Output "Windows setup created: $(Join-Path $outputPath 'FlCalculator-Setup.exe')"
    Write-Output "Portable app created: $portablePath"
    Write-Output "Release installer created: $(Join-Path $outputPath 'Install-LatestRelease.ps1')"
}
finally {
    Pop-Location
}
