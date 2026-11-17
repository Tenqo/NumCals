function New-SetupArgumentString {
    param(
        [string]$InstallPath,
        [string]$LogPath,
        [string]$ShortcutChoice
    )

    $taskArgument = if ($ShortcutChoice -eq 'yes') { 'desktopicon' } else { '!desktopicon' }
    $quotedPath = '"' + $InstallPath + '"'
    $quotedLog = '"' + $LogPath + '"'
    $arguments = @(
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        "/DIR=$quotedPath",
        "/LOG=$quotedLog",
        "/TASKS=`"$taskArgument`""
    )
    return $arguments -join ' '
}

function Invoke-SetupInstall {
    param(
        [hashtable]$Settings,
        [scriptblock]$ReleaseProvider,
        [scriptblock]$DownloadRequest,
        [scriptblock]$SetupProcessLauncher
    )

    Assert-SupportedArchitecture
    Assert-InstallDirectorySafe -InstallPath $Settings.installPath

    $downloadDirectory = Join-Path $script:WorkDirectory 'downloads'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $setupPath = Join-Path $downloadDirectory 'NumCals-Setup.exe'
    $logPath = Join-Path $downloadDirectory 'setup.log'

    Write-Status 'Checking for the latest release...'
    $latest = if ($ReleaseProvider) { & $ReleaseProvider } else { Get-LatestRelease }
    if ($Settings.releaseTag -and $latest.Release.tag_name -ne $Settings.releaseTag) {
        Write-Status "Update available: $($latest.Release.tag_name)."
    }

    Write-Status 'Downloading and verifying the release...'
    $downloadParameters = @{
        Url = $latest.Asset.browser_download_url
        Destination = $setupPath
        ExpectedSize = [long]$latest.Asset.size
        ExpectedDigest = [string]$latest.Asset.digest
    }
    if ($DownloadRequest) {
        $downloadParameters.DownloadRequest = $DownloadRequest
    }
    Invoke-VerifiedDownload @downloadParameters
    Write-Status 'Release download verified.' -Level Success

    $arguments = New-SetupArgumentString -InstallPath $Settings.installPath `
        -LogPath $logPath -ShortcutChoice $Settings.shortcutChoice

    Write-Status 'Applying the update...'

    $process = if ($SetupProcessLauncher) {
        & $SetupProcessLauncher $setupPath $arguments
    } else {
        Start-Process -FilePath $setupPath `
            -ArgumentList ($arguments -join ' ') -PassThru -WindowStyle Hidden
    }
    $process.WaitForExit()
    $process.Refresh()

    if ($process.ExitCode -ne 0) {
        $reason = Get-InstallerErrorDescription -ExitCode $process.ExitCode
        $diagnosticPath = Save-InstallerDiagnosticLog -LogPath $logPath

        $diagnosticMessage = if ($diagnosticPath) {
            " Installer log retained at: $diagnosticPath"
        } else {
            ' No installer log was produced.'
        }
        throw "Installation failed with code $($process.ExitCode). $reason$diagnosticMessage Check the log, confirm the selected folder is writable, and run the installer again."
    }

    $installedExecutable = Join-Path $Settings.installPath 'NumCals.exe'
    if (-not (Test-Path -LiteralPath $installedExecutable -PathType Leaf)) {
        $diagnosticPath = Save-InstallerDiagnosticLog -LogPath $logPath
        $diagnosticMessage = if ($diagnosticPath) {
            " Installer log retained at: $diagnosticPath"
        } else {
            ''
        }
        throw "The installer reported success, but NumCals.exe was not found in the selected folder.$diagnosticMessage Review the installer log and confirm the selected folder is accessible."
    }

    $Settings.releaseTag = [string]$latest.Release.tag_name
    $Settings.version = [string]$latest.Release.tag_name
    Write-PersistedSettings -Settings $Settings
    try {
        Install-CommandLineEntryPoint
    } catch {
        Write-Status "The app installed, but the NumCals command could not be registered: $($_.Exception.Message). You can still launch the app from $($Settings.installPath)." -Level Warning
    }

    Write-Status "NumCals $($latest.Release.tag_name) installed successfully." -Level Success
    Write-Status 'Installation completed successfully.' -Level Success
    $script:InstallationCompleted = $true
    Clear-InstallerWorkDirectory
}

function Invoke-InstallerCommand {
    param([string]$Command)

    if ($Command -eq 'help') {
        Show-CommandHelp
        return
    }
    if ($Command -eq 'exit') {
        return
    }
    if ($Command -eq 'update' -or $Command -eq 'upgrade') {
        $saved = Read-PersistedSettings
        if (-not $saved) {
            throw 'No saved installation was found. Run the PowerShell installer to install NumCals.'
        }
        if ($saved.repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            $script:RepositoryName = [string]$saved.repository
        }

        $installPath = Resolve-InstallPath -InputPath ([string]$saved.installPath)
        $installedExecutable = Join-Path $installPath 'NumCals.exe'
        if (-not (Test-Path -LiteralPath $installedExecutable -PathType Leaf)) {
            throw "The saved installation is missing NumCals.exe at $installPath. Run the installer again to repair it."
        }
        [void](Assert-InstalledExecutable -ExecutablePath $installedExecutable)

        $latest = Get-LatestRelease
        $installedTag = Get-InstalledReleaseTag -ExecutablePath $installedExecutable
        $decision = Get-InstallationDecision -ExecutableExists $true `
            -InstalledReleaseTag $installedTag -LatestReleaseTag ([string]$latest.Release.tag_name)
        if ($decision -eq 'Current' -and $Command -eq 'update') {
            Write-Status "NumCals is already up to date ($($latest.Release.tag_name))." -Level Success
            $script:InstallationCompleted = $true
            return
        }
        if ($decision -eq 'NewerInstalled') {
            Write-Status "The installed version $installedTag is newer than the latest release $($latest.Release.tag_name). It was left unchanged." -Level Warning
            $script:InstallationCompleted = $true
            return
        }
        if ($decision -eq 'UnknownVersion') {
            Write-Status "The installed version could not be determined, so it was left unchanged to prevent an accidental downgrade." -Level Warning
            $script:InstallationCompleted = $true
            return
        }

        Invoke-SetupInstall -Settings @{
            repository = $script:RepositoryName
            installPath = $installPath
            shortcutChoice = [string]$saved.shortcutChoice
            releaseTag = $installedTag
        }
        return
    }
    if ($Command -eq 'remove') {
        $confirmation = Read-Choice `
            -Prompt 'Remove NumCals from this computer?' `
            -Options @(
                [pscustomobject]@{ value = 'yes'; label = 'Yes' },
                [pscustomobject]@{ value = 'no'; label = 'No' }
            )
        if ($confirmation -ne 'yes') {
            Write-Status 'Removal canceled.' -Level Warning
            return
        }

        $saved = Read-PersistedSettings
        $installPath = Join-Path $env:LOCALAPPDATA 'Programs\NumCals'
        if ($saved -and -not [string]::IsNullOrWhiteSpace([string]$saved.installPath)) {
            $installPath = [string]$saved.installPath
        }
        Invoke-Uninstall -InstallPath $installPath
    }
}

function Invoke-InstallerWorkflow {
    param([string]$Action)

    try {
        if ($env:OS -ne 'Windows_NT') {
            throw 'NumCals can only be installed on Windows.'
        } elseif (-not [string]::IsNullOrWhiteSpace($Action)) {
            $resolvedAction = Resolve-InstallerCommand -InputValue $Action
            if (-not $resolvedAction) {
                Write-Status "Unknown command '$Action'. Type 'NumCals help' for available commands." -Level Warning
                Show-CommandHelp
                $script:ExitCode = 1
            } else {
                $commandLabel = if ($resolvedAction -eq 'exit') { 'exit' } else { "NumCals $resolvedAction" }
                Write-Status "Command: $commandLabel"
                try {
                    Invoke-InstallerCommand -Command $resolvedAction
                } catch {
                    Write-Status "$($resolvedAction.Substring(0, 1).ToUpperInvariant() + $resolvedAction.Substring(1)) failed: $($_.Exception.Message)" -Level Error
                    $script:ExitCode = 1
                }
            }
        } else {
            Show-InstallerBanner
            Write-Host 'Welcome to System Calculator' -ForegroundColor Gray
            [void](Read-Host 'Press Enter to continue')
            Show-SystemInformation
            Assert-SupportedArchitecture
            $settings = Read-InstallSettings
            Assert-InstallDirectorySafe -InstallPath $settings.installPath

            $installationReady = $false
            try {
                $installedExecutable = Join-Path $settings.installPath 'NumCals.exe'
                if (Test-Path -LiteralPath $installedExecutable -PathType Leaf) {
                    $latest = Get-LatestRelease
                    $installedTag = Get-InstalledReleaseTag -ExecutablePath $installedExecutable
                    $decision = Get-InstallationDecision -ExecutableExists $true `
                        -InstalledReleaseTag $installedTag -LatestReleaseTag ([string]$latest.Release.tag_name)
                    if ($decision -eq 'Current' -or $decision -eq 'NewerInstalled' -or
                        $decision -eq 'UnknownVersion') {
                        if ($installedTag) {
                            $settings.releaseTag = $installedTag
                            $settings.version = $installedTag
                        }
                        Write-PersistedSettings -Settings $settings
                        try {
                            Install-CommandLineEntryPoint
                        } catch {
                            Write-Status "The app is current, but the NumCals command could not be registered: $($_.Exception.Message). You can still launch the app from $($settings.installPath)." -Level Warning
                        }
                        if ($decision -eq 'Current') {
                            Write-Status "NumCals is already up to date ($($latest.Release.tag_name))." -Level Success
                        } elseif ($decision -eq 'NewerInstalled') {
                            Write-Status "The installed version $installedTag is newer than the latest release $($latest.Release.tag_name). It was left unchanged." -Level Warning
                        } else {
                            Write-Status "The installed version could not be determined, so it was left unchanged to prevent an accidental downgrade." -Level Warning
                        }
                        $script:InstallationCompleted = $true
                    } else {
                        $settings.releaseTag = $installedTag
                        Invoke-SetupInstall -Settings $settings
                    }
                } else {
                    Invoke-SetupInstall -Settings $settings
                }
                $installationReady = $true
            } catch {
                Write-Status "Installation failed: $($_.Exception.Message)" -Level Error
            }

            if ($installationReady) {
                Show-CommandHelp
                while ($true) {
                    $inputValue = Read-Host 'Command (enter a number or command)'
                    $command = Resolve-InstallerCommand -InputValue $inputValue
                    if (-not $command) {
                        Write-Status "Unknown command '$inputValue'. Type 'NumCals help' for available commands." -Level Warning
                        continue
                    }

                    $commandLabel = if ($command -eq 'exit') { 'exit' } else { "NumCals $command" }
                    Write-Status "Command: $commandLabel"
                    if ($command -eq 'exit') { break }

                    try {
                        Invoke-InstallerCommand -Command $command
                    } catch {
                        Write-Status "$($command.Substring(0, 1).ToUpperInvariant() + $command.Substring(1)) failed: $($_.Exception.Message)" -Level Error
                    }
                }
            }
        }
    } catch {
        Write-Status $_.Exception.Message -Level Error
        $script:ExitCode = 1
    } finally {
        Clear-InstallerWorkDirectory
        Show-SessionSummary
    }

    if ($script:ExitCode -ne 0) {
        exit $script:ExitCode
    }
}
