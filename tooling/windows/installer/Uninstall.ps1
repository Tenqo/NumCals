function Invoke-Uninstall {
    param([string]$InstallPath)

    $InstallPath = Resolve-InstallPath -InputPath $InstallPath
    $installedExecutable = Join-Path $InstallPath 'NumCals.exe'
    [void](Assert-InstalledExecutable -ExecutablePath $installedExecutable)

    $uninstaller = Join-Path $InstallPath 'unins000.exe'
    if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
        throw "The NumCals uninstaller was not found at $uninstaller."
    }

    $uninstallLogPath = Join-Path ([System.IO.Path]::GetTempPath()) `
        "NumCals-uninstall-$([guid]::NewGuid().ToString('N')).log"
    $arguments = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="' + $uninstallLogPath + '"'
    Write-Status 'Removing NumCals...'
    $process = Start-Process -FilePath $uninstaller `
        -ArgumentList $arguments `
        -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        $diagnosticPath = Save-InstallerDiagnosticLog -LogPath $uninstallLogPath
        $diagnosticMessage = if ($diagnosticPath) {
            " Uninstaller log retained at: $diagnosticPath"
        } else {
            ' No uninstaller log was produced.'
        }
        throw "Uninstallation failed with code $($process.ExitCode).$diagnosticMessage Confirm the installation folder is accessible and review the log before trying again."
    }

    if (Test-Path -LiteralPath $installedExecutable -PathType Leaf) {
        $diagnosticPath = Save-InstallerDiagnosticLog -LogPath $uninstallLogPath
        $diagnosticMessage = if ($diagnosticPath) {
            " Uninstaller log retained at: $diagnosticPath"
        } else {
            ''
        }
        throw "The uninstaller returned success, but NumCals.exe remains at $installedExecutable. Installation state and command registration were left unchanged.$diagnosticMessage"
    }

    if (Test-Path -LiteralPath $uninstallLogPath -PathType Leaf) {
        Remove-Item -LiteralPath $uninstallLogPath -Force
    }

    if (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:SettingsPath -Force
    }
    Remove-CommandLineEntryPoint
    Write-Status 'NumCals was removed.' -Level Success
}
