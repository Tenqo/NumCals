param(
    [string]$Repository = 'Tenqo/SysCalculator',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Repository must use the owner/repository format, for example 'Tenqo/SysCalculator'."
}

$script:RepositoryName = $Repository
$script:WorkDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "SysCalculator-Install-$([guid]::NewGuid().ToString('N'))"
$script:SettingsPath = Join-Path $env:LOCALAPPDATA 'Tenqo Digital\SysCalculator\install-state.json'

function Resolve-Choice {
    param(
        [string]$InputValue,
        [object[]]$Options
    )

    $normalized = $InputValue.Trim()
    foreach ($option in $Options) {
        if ($normalized -ieq [string]$option.value -or $normalized -ieq [string]$option.label) {
            return [string]$option.value
        }
    }

    if ($normalized -match '^\d+$') {
        $number = [int]$normalized
        if ($number -ge 1 -and $number -le $Options.Count) {
            return [string]$Options[$number - 1].value
        }
    }

    return $null
}

function Read-Choice {
    param(
        [string]$Prompt,
        [object[]]$Options
    )

    Write-Host ''
    Write-Host $Prompt
    for ($index = 0; $index -lt $Options.Count; $index++) {
        Write-Host "[$($index + 1)] $($Options[$index].label)"
    }

    while ($true) {
        $inputValue = Read-Host 'Enter a number or option name'
        $answer = Resolve-Choice -InputValue $inputValue -Options $Options
        if ($null -ne $answer) {
            return $answer
        }
        Write-Host 'That choice is not valid. Choose one of the displayed options.' -ForegroundColor Yellow
    }
}

function Resolve-InstallPath {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath) -or
        $InputPath.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0 -or
        $InputPath.Contains('"')) {
        throw 'The installation path is empty or contains unsupported characters.'
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($InputPath.Trim())
    } catch {
        throw "The installation path is invalid: $($_.Exception.Message)"
    }

    $rootPath = [System.IO.Path]::GetPathRoot($fullPath).TrimEnd('\')
    if ($fullPath.TrimEnd('\') -eq $rootPath) {
        throw 'Choose a folder below the drive root, not the drive root itself.'
    }

    return $fullPath
}

function Read-InstallSettings {
    $defaultPath = Join-Path $env:LOCALAPPDATA 'Programs\SysCalculator'
    $savedSettings = Read-PersistedSettings
    if ($savedSettings -and $savedSettings.repository -eq $script:RepositoryName -and
        -not [string]::IsNullOrWhiteSpace([string]$savedSettings.installPath)) {
        $defaultPath = [string]$savedSettings.installPath
    }

    $locationChoice = Read-Choice -Prompt 'Choose installation location:' -Options @(
        [pscustomobject]@{ value = 'default'; label = "Default location ($defaultPath)" },
        [pscustomobject]@{ value = 'custom'; label = 'Custom location' }
    )

    if ($locationChoice -eq 'custom') {
        while ($true) {
            $customPath = Read-Host 'Enter the custom installation folder'
            try {
                $installPath = Resolve-InstallPath -InputPath $customPath
                break
            } catch {
                Write-Host $_.Exception.Message -ForegroundColor Yellow
            }
        }
    } else {
        $installPath = Resolve-InstallPath -InputPath $defaultPath
    }

    $shortcutChoice = Read-Choice -Prompt 'Create a desktop shortcut?' -Options @(
        [pscustomobject]@{ value = 'yes'; label = 'Yes' },
        [pscustomobject]@{ value = 'no'; label = 'No' },
        [pscustomobject]@{ value = 'skip'; label = 'Skip' }
    )

    Write-Host ''
    Write-Host "Selected installation location: $installPath"
    Write-Host "Desktop shortcut: $shortcutChoice"

    return @{
        repository = $script:RepositoryName
        installPath = $installPath
        shortcutChoice = $shortcutChoice
        releaseTag = if ($savedSettings) { [string]$savedSettings.releaseTag } else { '' }
    }
}

function Write-PersistedSettings {
    param([hashtable]$Settings)

    $directory = Split-Path -Parent $script:SettingsPath
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporarySettings = "$script:SettingsPath.tmp"
    $json = $Settings | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText(
        $temporarySettings,
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )

    if (Test-Path -LiteralPath $script:SettingsPath) {
        [System.IO.File]::Replace($temporarySettings, $script:SettingsPath, $null)
    } else {
        [System.IO.File]::Move($temporarySettings, $script:SettingsPath)
    }
}

function Read-PersistedSettings {
    if (-not (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)) {
        return $null
    }
    return Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json
}

function Get-LatestRelease {
    $releaseUrl = "https://api.github.com/repos/$script:RepositoryName/releases/latest"
    $headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'SysCalculatorInstaller'
    }
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -eq 'SysCalculator-Setup.exe' } |
        Select-Object -First 1

    if ($null -eq $asset) {
        throw "The latest release for $script:RepositoryName does not contain SysCalculator-Setup.exe."
    }

    return [pscustomobject]@{
        Release = $release
        Asset = $asset
    }
}

function Invoke-VerifiedDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [long]$ExpectedSize,
        [string]$ExpectedDigest
    )

    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination -Headers @{
        Accept = 'application/octet-stream'
        'User-Agent' = 'SysCalculatorInstaller'
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        throw 'The download completed without creating the installer file.'
    }

    $actualSize = (Get-Item -LiteralPath $Destination).Length
    if ($actualSize -le 0 -or ($ExpectedSize -gt 0 -and $actualSize -ne $ExpectedSize)) {
        throw "The downloaded installer size is invalid (expected $ExpectedSize bytes, received $actualSize bytes)."
    }

    if ($ExpectedDigest -match '^sha256:([a-fA-F0-9]{64})$') {
        $actualDigest = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($actualDigest -ine $Matches[1]) {
            throw 'The installer SHA-256 checksum does not match GitHub release metadata.'
        }
    }
}

function Get-InstallerErrorDescription {
    param(
        [int]$ExitCode,
        [string]$LogPath
    )

    $description = switch ($ExitCode) {
        1 { 'Setup could not initialize.' }
        2 { 'Setup was canceled before installation began.' }
        3 { 'Setup could not prepare the installation.' }
        4 { 'A fatal error occurred during installation.' }
        5 { 'Setup was canceled while installation was in progress.' }
        6 { 'Setup was terminated by a debugger.' }
        7 { 'Setup cannot continue because the preparation stage failed.' }
        8 { 'Setup cannot continue until Windows is restarted.' }
        default { 'Setup returned an undocumented error code.' }
    }

    if (-not [string]::IsNullOrWhiteSpace($LogPath) -and
        (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        $logTail = @(Get-Content -LiteralPath $LogPath -Tail 8)
        if ($logTail.Count -gt 0) {
            $description += ' Installer log: ' + ($logTail -join ' | ')
        }
    }

    return $description
}

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
    param([hashtable]$Settings)

    $downloadDirectory = Join-Path $script:WorkDirectory 'downloads'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $setupPath = Join-Path $downloadDirectory 'SysCalculator-Setup.exe'
    $logPath = Join-Path $downloadDirectory 'setup.log'
    Remove-Item -LiteralPath $setupPath, $logPath -Force -ErrorAction SilentlyContinue

    Write-Host ''
    Write-Host 'Checking for the latest SysCalculator release...'
    $latest = Get-LatestRelease
    if ($Settings.releaseTag -and $latest.Release.tag_name -ne $Settings.releaseTag) {
        Write-Host "Updating from $($Settings.releaseTag) to $($latest.Release.tag_name)."
    }

    Write-Host 'Downloading latest release...'
    Invoke-VerifiedDownload -Url $latest.Asset.browser_download_url `
        -Destination $setupPath -ExpectedSize ([long]$latest.Asset.size) `
        -ExpectedDigest ([string]$latest.Asset.digest)
    Write-Host 'Download completed and verified.'

    $arguments = New-SetupArgumentString -InstallPath $Settings.installPath `
        -LogPath $logPath -ShortcutChoice $Settings.shortcutChoice

    Write-Host ''
    Write-Host "Starting PowerShell installation in $($Settings.installPath)..."
    Write-Host 'The installation wizard will not be opened.'
    Write-Host 'Installing SysCalculator...'

    $process = Start-Process -FilePath $setupPath `
        -ArgumentList ($arguments -join ' ') -PassThru -WindowStyle Hidden
    $lastLogPosition = 0
    $lastProgressUpdate = [DateTime]::UtcNow
    while (-not $process.HasExited) {
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            $logStream = [System.IO.File]::Open(
                $logPath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite
            )
            try {
                [void]$logStream.Seek($lastLogPosition, [System.IO.SeekOrigin]::Begin)
                $reader = New-Object System.IO.StreamReader($logStream)
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    if ($line) {
                        Write-Host "  $line"
                    }
                }
                $lastLogPosition = $logStream.Position
                $reader.Dispose()
            } finally {
                $logStream.Dispose()
            }
        }

        if (([DateTime]::UtcNow - $lastProgressUpdate).TotalSeconds -ge 1) {
            Write-Progress -Id 1 -Activity 'Installing SysCalculator' `
                -Status 'Installer is running; exact percentage is not available.'
            $lastProgressUpdate = [DateTime]::UtcNow
        }
        [void]$process.WaitForExit(250)
    }
    $process.Refresh()
    Write-Progress -Id 1 -Activity 'Installing SysCalculator' -Completed

    if ($process.ExitCode -ne 0) {
        $reason = Get-InstallerErrorDescription -ExitCode $process.ExitCode -LogPath $logPath
        throw "Installation failed with code $($process.ExitCode).`nReason: $reason"
    }

    $installedExecutable = Join-Path $Settings.installPath 'SysCalculator.exe'
    if (-not (Test-Path -LiteralPath $installedExecutable -PathType Leaf)) {
        throw 'The installer reported success, but SysCalculator.exe was not found in the selected folder.'
    }

    $Settings.releaseTag = [string]$latest.Release.tag_name
    $Settings.version = [string]$latest.Release.tag_name
    Write-PersistedSettings -Settings $Settings

    Write-Host ''
    Write-Host 'Installation completed successfully!' -ForegroundColor Green
}

function Invoke-Uninstall {
    param([string]$InstallPath)

    $uninstaller = Join-Path $InstallPath 'unins000.exe'
    if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
        throw "The SysCalculator uninstaller was not found at $uninstaller."
    }

    Write-Host 'Removing the existing SysCalculator installation...'
    $process = Start-Process -FilePath $uninstaller `
        -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' `
        -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "Uninstallation failed with code $($process.ExitCode)."
    }
}

function Show-CommandHelp {
    Write-Host ''
    Write-Host 'Available commands:'
    Write-Host '  SysCalculator update          Check for and install an available update.'
    Write-Host '  SysCalculator upgrade         Install the latest release.'
    Write-Host '  SysCalculator remove/install  Confirm removal, then install the latest release.'
    Write-Host '  SysCalculator help            Show this help.'
    Write-Host '  exit                          Close this PowerShell installer session.'
    Write-Host ''
}

function Invoke-InstallerSelfTest {
    $options = @(
        [pscustomobject]@{ value = 'yes'; label = 'Yes' },
        [pscustomobject]@{ value = 'no'; label = 'No' },
        [pscustomobject]@{ value = 'skip'; label = 'Skip' }
    )

    if ((Resolve-Choice -InputValue '1' -Options $options) -ne 'yes' -or
        (Resolve-Choice -InputValue 'SKIP' -Options $options) -ne 'skip' -or
        $null -ne (Resolve-Choice -InputValue '4' -Options $options)) {
        throw 'Installer option parsing self-test failed.'
    }

    $testInstallPath = Join-Path $env:TEMP 'SysCalculator-SelfTest'
    if (-not [System.IO.Path]::IsPathRooted(
        (Resolve-InstallPath -InputPath $testInstallPath)
    )) {
        throw 'Installer path validation self-test failed.'
    }

    $invalidPathRejected = $false
    try {
        [void](Resolve-InstallPath -InputPath 'C:\Sys"Calculator')
    } catch {
        $invalidPathRejected = $true
    }
    if (-not $invalidPathRejected) {
        throw 'Installer accepted a path containing a quote.'
    }

    $silentArguments = New-SetupArgumentString `
        -InstallPath 'C:\Users\Test User\SysCalculator' `
        -LogPath 'C:\Temp\setup.log' -ShortcutChoice 'skip'
    if ($silentArguments -notmatch '/VERYSILENT' -or
        $silentArguments -notmatch '/TASKS="!desktopicon"') {
        throw 'PowerShell installer did not select silent mode or skip the shortcut task.'
    }

    $shortcutArguments = New-SetupArgumentString `
        -InstallPath 'C:\Users\Test User\SysCalculator' `
        -LogPath 'C:\Temp\setup.log' -ShortcutChoice 'yes'
    if ($shortcutArguments -notmatch '/TASKS="desktopicon"') {
        throw 'PowerShell installer did not select desktop shortcut creation.'
    }

    $installerSource = Get-Content -LiteralPath $PSCommandPath -Raw
    $selfTestStart = $installerSource.IndexOf('function Invoke-InstallerSelfTest')
    if ($selfTestStart -lt 0) {
        throw 'PowerShell installer entry point could not be verified.'
    }
    $installerRuntime = $installerSource.Substring(0, $selfTestStart)
    if ($installerRuntime -match 'System\.Windows\.Forms|Start-WizardWindow|WizardClient') {
        throw 'PowerShell installer contains a graphical wizard launch path.'
    }

    $setupDefinition = Join-Path $PSScriptRoot '..\..\packaging\windows\SysCalculator-Setup.iss'
    $setupSource = Get-Content -LiteralPath $setupDefinition -Raw
    if ($setupSource -notmatch '(?m)^WizardStyle=modern' -or
        $setupSource -notmatch '(?m)^AppName=SysCalculator') {
        throw 'The standalone setup executable does not declare the SysCalculator graphical wizard.'
    }

    $cancelDescription = Get-InstallerErrorDescription -ExitCode 2 `
        -LogPath (Join-Path $script:WorkDirectory 'no-such-installer.log')
    if ($cancelDescription -notlike '*canceled before installation began*') {
        throw 'Installer cancellation explanation self-test failed.'
    }
    if ((Get-InstallerErrorDescription -ExitCode 7 -LogPath '') -notlike '*preparation stage failed*' -or
        (Get-InstallerErrorDescription -ExitCode 8 -LogPath '') -notlike '*Windows is restarted*') {
        throw 'Installer preparation/restart error explanations are incorrect.'
    }

    Write-Host 'Installer self-tests passed: console choices, path validation, silent setup arguments, media separation, and cancellation reporting.'
}

try {
    if ($SelfTest) {
        Invoke-InstallerSelfTest
        return
    }

    if ($env:OS -ne 'Windows_NT') {
        throw 'SysCalculator can only be installed on Windows.'
    }

    Write-Host 'SysCalculator PowerShell Installer'
    Write-Host 'This method stays in PowerShell and does not open installation media.'
    $settings = Read-InstallSettings

    while ($true) {
        try {
            Invoke-SetupInstall -Settings $settings
            break
        } catch {
            Write-Host ''
            Write-Host $_.Exception.Message -ForegroundColor Red
            $retry = Read-Choice -Prompt 'Would you like to try again?' -Options @(
                [pscustomobject]@{ value = 'yes'; label = 'Yes' },
                [pscustomobject]@{ value = 'no'; label = 'No' }
            )
            if ($retry -ne 'yes') {
                Write-Host 'Installation stopped. Your selected location and shortcut settings are unchanged.'
                break
            }
        }
    }

    Show-CommandHelp
    while ($true) {
        $command = (Read-Host 'Enter a command (SysCalculator help)').Trim()
        if ($command -match '^(?i:exit|quit)$') {
            break
        }
        if ($command -match '^(?i:SysCalculator\s+help|help)$') {
            Show-CommandHelp
            continue
        }
        if ($command -match '^(?i:SysCalculator\s+update|SysCalculator\s+upgrade)$') {
            $forceUpgrade = $command -match '(?i:upgrade)$'
            try {
                $latest = Get-LatestRelease
                $saved = Read-PersistedSettings
                if (-not $forceUpgrade -and $saved -and
                    [string]$saved.releaseTag -eq [string]$latest.Release.tag_name) {
                    Write-Host "SysCalculator is already up to date ($($latest.Release.tag_name))." -ForegroundColor Green
                    continue
                }

                if (-not $saved) {
                    $saved = $settings
                }
                Invoke-SetupInstall -Settings @{
                    repository = $script:RepositoryName
                    installPath = [string]$saved.installPath
                    shortcutChoice = [string]$saved.shortcutChoice
                    releaseTag = [string]$saved.releaseTag
                }
            } catch {
                Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            continue
        }
        if ($command -match '^(?i:SysCalculator\s+remove/install)$') {
            $confirmation = Read-Choice `
                -Prompt 'Remove the existing SysCalculator installation and install it again?' `
                -Options @(
                    [pscustomobject]@{ value = 'yes'; label = 'Yes' },
                    [pscustomobject]@{ value = 'no'; label = 'No' }
                )
            if ($confirmation -ne 'yes') {
                Write-Host 'Reinstallation canceled.'
                continue
            }

            try {
                $saved = Read-PersistedSettings
                if (-not $saved) {
                    throw 'Saved installation settings were not found. Run the installer again first.'
                }
                Invoke-Uninstall -InstallPath ([string]$saved.installPath)
                Invoke-SetupInstall -Settings @{
                    repository = $script:RepositoryName
                    installPath = [string]$saved.installPath
                    shortcutChoice = [string]$saved.shortcutChoice
                    releaseTag = [string]$saved.releaseTag
                }
            } catch {
                Write-Host "Remove/reinstall failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            continue
        }

        Write-Host "Unknown command '$command'. Type 'SysCalculator help' for available commands." -ForegroundColor Yellow
    }
} finally {
    if (Test-Path -LiteralPath $script:WorkDirectory) {
        Remove-Item -LiteralPath $script:WorkDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
