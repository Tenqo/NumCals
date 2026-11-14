param(
    [string]$Repository = 'Tenqo/SysCalculator',
    [string]$Action,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Repository must use the owner/repository format, for example 'Tenqo/SysCalculator'."
}

$script:RepositoryName = $Repository
$script:WorkDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "SysCalculator-Install-$([guid]::NewGuid().ToString('N'))"
$script:SettingsPath = Join-Path $env:LOCALAPPDATA 'Tenqo Digital\SysCalculator\install-state.json'
$script:CommandDirectory = Join-Path (Split-Path -Parent $script:SettingsPath) 'cli'
$script:CommandScriptPath = Join-Path $script:CommandDirectory 'Install-LatestRelease.ps1'
$script:InstallerScriptPath = $PSCommandPath
$script:HadErrors = $false
$script:HadWarnings = $false
$script:InstallationCompleted = $false
$script:ExitCode = 0

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
        Write-Status 'That choice is not valid. Choose one of the displayed options.' -Level Warning
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
                Write-Status $_.Exception.Message -Level Warning
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
    param(
        [hashtable]$Settings,
        [string]$Path = $script:SettingsPath
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporarySettings = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $json = $Settings | ConvertTo-Json -Depth 5
    try {
        [System.IO.File]::WriteAllText(
            $temporarySettings,
            $json,
            (New-Object System.Text.UTF8Encoding($false))
        )

        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Replace($temporarySettings, $Path, $null)
        } else {
            [System.IO.File]::Move($temporarySettings, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $temporarySettings -PathType Leaf) {
            Remove-Item -LiteralPath $temporarySettings -Force
        }
    }
}

function Read-PersistedSettings {
    param([string]$Path = $script:SettingsPath)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-StatusStyle {
    param([ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Level)

    switch ($Level) {
        'Success' { return [pscustomobject]@{ Symbol = [char]0x2713; Color = [ConsoleColor]::Green } }
        'Warning' { return [pscustomobject]@{ Symbol = '!'; Color = [ConsoleColor]::Yellow } }
        'Error' { return [pscustomobject]@{ Symbol = [char]0x2717; Color = [ConsoleColor]::Red } }
        default { return [pscustomobject]@{ Symbol = '>'; Color = [ConsoleColor]::Cyan } }
    }
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $style = Get-StatusStyle -Level $Level
    $messageLine = ($Message -replace '[\r\n]+', ' ').Trim()
    Write-Host "[$($style.Symbol)] $messageLine" -ForegroundColor $style.Color

    if ($Level -eq 'Error') {
        $script:HadErrors = $true
        $script:ExitCode = 1
    } elseif ($Level -eq 'Warning') {
        $script:HadWarnings = $true
    }
}

function Show-InstallerBanner {
    Write-Host ''
    Write-Host '  SYSTEM CALCULATOR' -ForegroundColor Cyan
    Write-Host '  PowerShell installer' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "  [$([char]0x2713)] Completed  " -NoNewline -ForegroundColor Green
    Write-Host '[!] Warning  ' -NoNewline -ForegroundColor Yellow
    Write-Host "[$([char]0x2717)] Error" -ForegroundColor Red
    Write-Host ''
}

function Show-SessionSummary {
    if ($script:HadErrors) {
        Write-Status 'If installation did not complete or SysCalculator is missing, review the red errors above.' -Level Warning
    } elseif ($script:HadWarnings) {
        Write-Status 'Session completed with warnings. Review the yellow messages above.' -Level Warning
    } else {
        Write-Status 'Session completed successfully.' -Level Success
    }
}

function Clear-InstallerWorkDirectory {
    if (-not (Test-Path -LiteralPath $script:WorkDirectory -PathType Container)) {
        return
    }

    Write-Status 'Cleaning up temporary installer files...'
    try {
        Remove-Item -LiteralPath $script:WorkDirectory -Recurse -Force
    } catch {
        Write-Status "Temporary file cleanup failed: $($_.Exception.Message)" -Level Warning
        return
    }
    Write-Status 'Installer cleanup completed successfully.' -Level Success
}

function Get-CommandLauncherContent {
    return "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0Install-LatestRelease.ps1`" -Action `"%*`"`r`n"
}

function Add-CommandDirectoryToPath {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @($userPath -split ';' | Where-Object { $_ })
    $userPathHasEntry = @($pathEntries | Where-Object {
        $_.TrimEnd('\') -ieq $script:CommandDirectory.TrimEnd('\')
    }).Count -gt 0

    if (-not $userPathHasEntry) {
        $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
            $script:CommandDirectory
        } else {
            "$userPath;$script:CommandDirectory"
        }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    }

    $processPathEntries = @($env:PATH -split ';' | Where-Object { $_ })
    $processPathHasEntry = @($processPathEntries | Where-Object {
        $_.TrimEnd('\') -ieq $script:CommandDirectory.TrimEnd('\')
    }).Count -gt 0
    if (-not $processPathHasEntry) {
        $env:PATH = if ([string]::IsNullOrWhiteSpace($env:PATH)) {
            $script:CommandDirectory
        } else {
            "$env:PATH;$script:CommandDirectory"
        }
    }
}

function Install-CommandLineEntryPoint {
    New-Item -ItemType Directory -Path $script:CommandDirectory -Force | Out-Null
    $installedScript = Join-Path $script:CommandDirectory 'Install-LatestRelease.ps1'
    $sourcePath = [System.IO.Path]::GetFullPath($script:InstallerScriptPath)
    if ($sourcePath -ine [System.IO.Path]::GetFullPath($installedScript)) {
        Copy-Item -LiteralPath $sourcePath -Destination $installedScript -Force
    }

    $launcherPath = Join-Path $script:CommandDirectory 'SysCalculator.cmd'
    [System.IO.File]::WriteAllText(
        $launcherPath,
        (Get-CommandLauncherContent),
        [System.Text.Encoding]::ASCII
    )
    Add-CommandDirectoryToPath
    Write-Status 'PowerShell command registered. Open a new PowerShell window to use SysCalculator.' -Level Success
}

function Remove-CommandLineFiles {
    param([string]$CommandDirectory)

    $filesToRemove = @('SysCalculator.cmd', 'Install-LatestRelease.ps1')

    foreach ($fileName in $filesToRemove) {
        $filePath = Join-Path $CommandDirectory $fileName
        if (Test-Path -LiteralPath $filePath -PathType Leaf) {
            Remove-Item -LiteralPath $filePath -Force
        }
    }

    if ((Test-Path -LiteralPath $CommandDirectory -PathType Container) -and
        @(Get-ChildItem -LiteralPath $CommandDirectory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $CommandDirectory -Force
    } elseif (Test-Path -LiteralPath $CommandDirectory -PathType Container) {
        $remainingNames = @(Get-ChildItem -LiteralPath $CommandDirectory -Force |
            ForEach-Object { $_.Name })
        Write-Status "Preserving other files in the command folder: $($remainingNames -join ', ')" -Level Warning
    }
}

function Remove-CommandLineEntryPoint {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $userPathEntries = @($userPath -split ';' | Where-Object {
        $_ -and $_.TrimEnd('\') -ine $script:CommandDirectory.TrimEnd('\')
    })
    if ($userPathEntries.Count -ne @($userPath -split ';' | Where-Object { $_ }).Count) {
        [Environment]::SetEnvironmentVariable('Path', ($userPathEntries -join ';'), 'User')
    }

    $processPathEntries = @($env:PATH -split ';' | Where-Object {
        $_ -and $_.TrimEnd('\') -ine $script:CommandDirectory.TrimEnd('\')
    })
    $env:PATH = $processPathEntries -join ';'

    Remove-CommandLineFiles -CommandDirectory $script:CommandDirectory
}

function Get-OperatingSystemArchitecture {
    param(
        [string]$ProcessArchitecture = $env:PROCESSOR_ARCHITECTURE,
        [string]$NativeArchitecture = $env:PROCESSOR_ARCHITEW6432,
        [bool]$Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
    )

    if (-not $Is64BitOperatingSystem) {
        return 'x86'
    }

    $architectureName = if ($NativeArchitecture) { $NativeArchitecture } else { $ProcessArchitecture }
    switch ($architectureName.ToUpperInvariant()) {
        'AMD64' { return 'x64' }
        'ARM64' { return 'ARM64' }
        default { return 'unknown' }
    }
}

function Assert-SupportedArchitecture {
    param([string]$Architecture = (Get-OperatingSystemArchitecture))

    if ($Architecture -notin @('x64', 'ARM64')) {
        throw "SysCalculator requires 64-bit Windows (x64 or ARM64). Detected architecture: $Architecture."
    }
}

function Show-SystemInformation {
    $version = [Environment]::OSVersion.Version
    $windowsName = if ($version.Build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
    $architecture = Get-OperatingSystemArchitecture

    Write-Host "Windows build: $windowsName (Build $($version.Build))" -ForegroundColor DarkGray
    Write-Host "Windows architecture: $architecture" -ForegroundColor DarkGray
    Write-Host ''
}

function Get-InstalledReleaseTag {
    param([string]$ExecutablePath)

    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
        return $null
    }

    $fileInformation = Assert-InstalledExecutable -ExecutablePath $ExecutablePath
    $fileVersion = $fileInformation.FileVersion
    if ($fileVersion -match '(\d+\.\d+\.\d+)') {
        return "v$($Matches[1])"
    }

    return $null
}

function Assert-InstalledExecutable {
    param([string]$ExecutablePath)

    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
        throw "SysCalculator.exe was not found at $ExecutablePath."
    }

    $fileInformation = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExecutablePath)
    if ($fileInformation.ProductName -ine 'SysCalculator') {
        throw "The executable at $ExecutablePath is not identified as the SysCalculator app."
    }

    return $fileInformation
}

function Get-InstallationDecision {
    param(
        [bool]$ExecutableExists,
        [string]$InstalledReleaseTag,
        [string]$LatestReleaseTag
    )

    if (-not $ExecutableExists) {
        return 'Install'
    }
    $installedMatch = [regex]::Match($InstalledReleaseTag, '^v?(\d+\.\d+\.\d+)$')
    $latestMatch = [regex]::Match($LatestReleaseTag, '^v?(\d+\.\d+\.\d+)$')
    if ($installedMatch.Success -and $latestMatch.Success) {
        $installedVersion = [version]$installedMatch.Groups[1].Value
        $latestVersion = [version]$latestMatch.Groups[1].Value
        if ($installedVersion -eq $latestVersion) {
            return 'Current'
        }
        if ($installedVersion -gt $latestVersion) {
            return 'NewerInstalled'
        }
        return 'Update'
    }
    return 'UnknownVersion'
}

function Assert-InstallDirectorySafe {
    param([string]$InstallPath)

    if (-not (Test-Path -LiteralPath $InstallPath -PathType Container)) {
        return
    }

    $installedExecutable = Join-Path $InstallPath 'SysCalculator.exe'
    if (Test-Path -LiteralPath $installedExecutable -PathType Leaf) {
        [void](Assert-InstalledExecutable -ExecutablePath $installedExecutable)
        return
    }

    if (@(Get-ChildItem -LiteralPath $InstallPath -Force).Count -gt 0) {
        throw "The selected folder is not empty and does not contain SysCalculator.exe: $InstallPath. Choose an empty folder to avoid overwriting unrelated files."
    }
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
        [string]$ExpectedDigest,
        [scriptblock]$DownloadRequest = {
            param([string]$DownloadUrl, [string]$OutputPath)
            Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $OutputPath -Headers @{
                Accept = 'application/octet-stream'
                'User-Agent' = 'SysCalculatorInstaller'
            }
        }
    )

    $downloadUri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$downloadUri) -or
        $downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ine 'github.com') {
        throw 'The release download URL is not a trusted HTTPS GitHub URL.'
    }
    if ($ExpectedSize -le 0) {
        throw 'The release metadata does not contain a valid asset size.'
    }
    if ($ExpectedDigest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
        throw 'The release metadata does not contain a valid SHA-256 digest.'
    }
    $expectedHash = $Matches[1]
    if (Test-Path -LiteralPath $Destination) {
        throw "Refusing to overwrite an existing download: $Destination"
    }

    $partialPath = "$Destination.$([guid]::NewGuid().ToString('N')).partial"
    try {
        try {
            & $DownloadRequest $Url $partialPath
        } catch {
            throw "Release download failed. No installer was run and the partial download will be removed. Check internet/proxy access to GitHub and try the command again. Certificate verification remains enabled. Details: $($_.Exception.Message)"
        }

        if (-not (Test-Path -LiteralPath $partialPath -PathType Leaf)) {
            throw 'The download completed without creating the installer file.'
        }

        $actualSize = (Get-Item -LiteralPath $partialPath).Length
        if ($actualSize -le 0 -or $actualSize -ne $ExpectedSize) {
            throw "The downloaded installer size is invalid (expected $ExpectedSize bytes, received $actualSize bytes)."
        }

        $actualDigest = (Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash
        if ($actualDigest -ine $expectedHash) {
            throw 'The installer SHA-256 checksum does not match GitHub release metadata.'
        }

        Move-Item -LiteralPath $partialPath -Destination $Destination
    } finally {
        if (Test-Path -LiteralPath $partialPath -PathType Leaf) {
            Remove-Item -LiteralPath $partialPath -Force
        }
    }
}

function Get-InstallerErrorDescription {
    param([int]$ExitCode)

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

    return $description
}

function Save-InstallerDiagnosticLog {
    param([string]$LogPath)

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        return $null
    }

    $diagnosticPath = Join-Path ([System.IO.Path]::GetTempPath()) `
        "SysCalculator-setup-$([guid]::NewGuid().ToString('N')).log"
    Move-Item -LiteralPath $LogPath -Destination $diagnosticPath
    return $diagnosticPath
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

    Assert-SupportedArchitecture
    Assert-InstallDirectorySafe -InstallPath $Settings.installPath

    $downloadDirectory = Join-Path $script:WorkDirectory 'downloads'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $setupPath = Join-Path $downloadDirectory 'SysCalculator-Setup.exe'
    $logPath = Join-Path $downloadDirectory 'setup.log'

    Write-Status 'Checking for the latest release...'
    $latest = Get-LatestRelease
    if ($Settings.releaseTag -and $latest.Release.tag_name -ne $Settings.releaseTag) {
        Write-Status "Update available: $($latest.Release.tag_name)."
    }

    Write-Status 'Downloading and verifying the release...'
    Invoke-VerifiedDownload -Url $latest.Asset.browser_download_url `
        -Destination $setupPath -ExpectedSize ([long]$latest.Asset.size) `
        -ExpectedDigest ([string]$latest.Asset.digest)
    Write-Status 'Release download verified.' -Level Success

    $arguments = New-SetupArgumentString -InstallPath $Settings.installPath `
        -LogPath $logPath -ShortcutChoice $Settings.shortcutChoice

    Write-Status 'Applying the update...'

    $process = Start-Process -FilePath $setupPath `
        -ArgumentList ($arguments -join ' ') -PassThru -WindowStyle Hidden
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

    $installedExecutable = Join-Path $Settings.installPath 'SysCalculator.exe'
    if (-not (Test-Path -LiteralPath $installedExecutable -PathType Leaf)) {
        $diagnosticPath = Save-InstallerDiagnosticLog -LogPath $logPath
        $diagnosticMessage = if ($diagnosticPath) {
            " Installer log retained at: $diagnosticPath"
        } else {
            ''
        }
        throw "The installer reported success, but SysCalculator.exe was not found in the selected folder.$diagnosticMessage Review the installer log and confirm the selected folder is accessible."
    }

    $Settings.releaseTag = [string]$latest.Release.tag_name
    $Settings.version = [string]$latest.Release.tag_name
    Write-PersistedSettings -Settings $Settings
    try {
        Install-CommandLineEntryPoint
    } catch {
        Write-Status "The app installed, but the SysCalculator command could not be registered: $($_.Exception.Message). You can still launch the app from $($Settings.installPath)." -Level Warning
    }

    Write-Status "SysCalculator $($latest.Release.tag_name) installed successfully." -Level Success
    Write-Status 'Installation completed successfully.' -Level Success
    $script:InstallationCompleted = $true
    Clear-InstallerWorkDirectory
}

function Invoke-Uninstall {
    param([string]$InstallPath)

    $InstallPath = Resolve-InstallPath -InputPath $InstallPath
    $installedExecutable = Join-Path $InstallPath 'SysCalculator.exe'
    [void](Assert-InstalledExecutable -ExecutablePath $installedExecutable)

    $uninstaller = Join-Path $InstallPath 'unins000.exe'
    if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
        throw "The SysCalculator uninstaller was not found at $uninstaller."
    }

    $uninstallLogPath = Join-Path ([System.IO.Path]::GetTempPath()) `
        "SysCalculator-uninstall-$([guid]::NewGuid().ToString('N')).log"
    $arguments = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="' + $uninstallLogPath + '"'
    Write-Status 'Removing SysCalculator...'
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
        throw "The uninstaller returned success, but SysCalculator.exe remains at $installedExecutable. Installation state and command registration were left unchanged.$diagnosticMessage"
    }

    if (Test-Path -LiteralPath $uninstallLogPath -PathType Leaf) {
        Remove-Item -LiteralPath $uninstallLogPath -Force
    }

    if (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:SettingsPath -Force
    }
    Remove-CommandLineEntryPoint
    Write-Status 'SysCalculator was removed.' -Level Success
}

function Show-CommandHelp {
    Write-Host ''
    Write-Host '  AVAILABLE COMMANDS' -ForegroundColor Cyan
    Write-Host '  [1] SysCalculator update     Install only when a newer release is available.' -ForegroundColor Gray
    Write-Host '  [2] SysCalculator upgrade    Reinstall the latest release.' -ForegroundColor Gray
    Write-Host '  [3] SysCalculator remove     Confirm and uninstall SysCalculator.' -ForegroundColor Gray
    Write-Host '  [4] SysCalculator help       Show this help.' -ForegroundColor Gray
    Write-Host '  [5] exit                     Close this PowerShell session.' -ForegroundColor Gray
    Write-Host ''
}

function Resolve-InstallerCommand {
    param([string]$InputValue)

    $tokens = @($InputValue.Trim() -split '\s+' | Where-Object { $_ })
    if ($tokens.Count -eq 0) {
        return $null
    }

    if ($tokens.Count -eq 1) {
        switch ($tokens[0]) {
            '1' { return 'update' }
            '2' { return 'upgrade' }
            '3' { return 'remove' }
            '4' { return 'help' }
            '5' { return 'exit' }
        }
    }

    if ($tokens[0] -ieq 'SysCalculator') {
        if ($tokens.Count -ne 2) {
            return $null
        }
        $verb = $tokens[1]
    } else {
        if ($tokens.Count -ne 1) {
            return $null
        }
        $verb = $tokens[0]
    }

    if ($verb -ieq 'update') { return 'update' }
    if ($verb -ieq 'upgrade') { return 'upgrade' }
    if ($verb -ieq 'remove') { return 'remove' }
    if ($verb -ieq 'help') { return 'help' }
    if ($verb -ieq 'exit' -or $verb -ieq 'quit') { return 'exit' }
    return $null
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
            throw 'No saved installation was found. Run the PowerShell installer to install SysCalculator.'
        }
        if ($saved.repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            $script:RepositoryName = [string]$saved.repository
        }

        $installPath = Resolve-InstallPath -InputPath ([string]$saved.installPath)
        $installedExecutable = Join-Path $installPath 'SysCalculator.exe'
        if (-not (Test-Path -LiteralPath $installedExecutable -PathType Leaf)) {
            throw "The saved installation is missing SysCalculator.exe at $installPath. Run the installer again to repair it."
        }
        [void](Assert-InstalledExecutable -ExecutablePath $installedExecutable)

        $latest = Get-LatestRelease
        $installedTag = Get-InstalledReleaseTag -ExecutablePath $installedExecutable
        $decision = Get-InstallationDecision -ExecutableExists $true `
            -InstalledReleaseTag $installedTag -LatestReleaseTag ([string]$latest.Release.tag_name)
        if ($decision -eq 'Current' -and $Command -eq 'update') {
            Write-Status "SysCalculator is already up to date ($($latest.Release.tag_name))." -Level Success
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
            -Prompt 'Remove SysCalculator from this computer?' `
            -Options @(
                [pscustomobject]@{ value = 'yes'; label = 'Yes' },
                [pscustomobject]@{ value = 'no'; label = 'No' }
            )
        if ($confirmation -ne 'yes') {
            Write-Status 'Removal canceled.' -Level Warning
            return
        }

        $saved = Read-PersistedSettings
        $installPath = Join-Path $env:LOCALAPPDATA 'Programs\SysCalculator'
        if ($saved -and -not [string]::IsNullOrWhiteSpace([string]$saved.installPath)) {
            $installPath = [string]$saved.installPath
        }
        Invoke-Uninstall -InstallPath $installPath
    }
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

    if ((Resolve-InstallerCommand -InputValue 'sYsCaLcUlAtOr uPdAtE') -ne 'update' -or
        (Resolve-InstallerCommand -InputValue 'SysCalculator UPGRADE') -ne 'upgrade' -or
        (Resolve-InstallerCommand -InputValue 'SYSCALCULATOR REMOVE') -ne 'remove' -or
        (Resolve-InstallerCommand -InputValue '1') -ne 'update' -or
        (Resolve-InstallerCommand -InputValue '2') -ne 'upgrade' -or
        (Resolve-InstallerCommand -InputValue '3') -ne 'remove' -or
        (Resolve-InstallerCommand -InputValue '4') -ne 'help' -or
        (Resolve-InstallerCommand -InputValue '5') -ne 'exit' -or
        (Resolve-InstallerCommand -InputValue 'rEmOvE') -ne 'remove' -or
        (Resolve-InstallerCommand -InputValue 'uPdAtE') -ne 'update' -or
        (Resolve-InstallerCommand -InputValue 'upGRADE') -ne 'upgrade' -or
        (Resolve-InstallerCommand -InputValue 'hElP') -ne 'help' -or
        (Resolve-InstallerCommand -InputValue 'EXIT') -ne 'exit' -or
        $null -ne (Resolve-InstallerCommand -InputValue 'SysCalculator remove/install')) {
        throw 'Installer command parsing self-test failed.'
    }
    if (-not (Get-CommandLauncherContent).Contains('-Action "%*"')) {
        throw 'PowerShell command launcher self-test failed.'
    }
    if ((Get-StatusStyle -Level Success).Color -ne [ConsoleColor]::Green -or
        (Get-StatusStyle -Level Warning).Color -ne [ConsoleColor]::Yellow -or
        (Get-StatusStyle -Level Error).Color -ne [ConsoleColor]::Red) {
        throw 'Installer status colors self-test failed.'
    }

    if ((Get-OperatingSystemArchitecture -ProcessArchitecture 'AMD64' -Is64BitOperatingSystem $true) -ne 'x64' -or
        (Get-OperatingSystemArchitecture -ProcessArchitecture 'x86' -NativeArchitecture 'ARM64' -Is64BitOperatingSystem $true) -ne 'ARM64' -or
        (Get-OperatingSystemArchitecture -ProcessArchitecture 'x86' -Is64BitOperatingSystem $false) -ne 'x86') {
        throw 'Windows architecture detection self-test failed.'
    }

    if ((Get-InstallationDecision -ExecutableExists $false -InstalledReleaseTag '' -LatestReleaseTag 'v1.0.2') -ne 'Install' -or
        (Get-InstallationDecision -ExecutableExists $true -InstalledReleaseTag 'v1.0.2' -LatestReleaseTag 'v1.0.2') -ne 'Current' -or
        (Get-InstallationDecision -ExecutableExists $true -InstalledReleaseTag 'v1.0.3' -LatestReleaseTag 'v1.0.2') -ne 'NewerInstalled' -or
        (Get-InstallationDecision -ExecutableExists $true -InstalledReleaseTag 'v1.0.1' -LatestReleaseTag 'v1.0.2') -ne 'Update' -or
        (Get-InstallationDecision -ExecutableExists $true -InstalledReleaseTag '' -LatestReleaseTag 'v1.0.2') -ne 'UnknownVersion') {
        throw 'Existing installation decision self-test failed.'
    }

    $unsupportedArchitectureRejected = $false
    try {
        Assert-SupportedArchitecture -Architecture 'x86'
    } catch {
        $unsupportedArchitectureRejected = $true
    }
    if (-not $unsupportedArchitectureRejected) {
        throw 'Installer did not reject unsupported 32-bit Windows.'
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
    $unicodeInstallPath = Resolve-InstallPath -InputPath (Join-Path $env:TEMP 'SysCalculator café')
    if ($unicodeInstallPath -notlike '*SysCalculator café') {
        throw 'Installer did not preserve a non-ASCII installation path.'
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

    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
        "SysCalculator-InstallerSelfTest-$([guid]::NewGuid().ToString('N'))"
    $testDiagnosticPath = $null
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    try {
        $testSettingsPath = Join-Path $testRoot 'install-state.json'
        $testSettings = @{
            repository = 'Tenqo/SysCalculator'
            installPath = Join-Path $testRoot 'SysCalculator'
            releaseTag = 'v1.0.2'
        }
        Write-PersistedSettings -Settings $testSettings -Path $testSettingsPath
        $readSettings = Read-PersistedSettings -Path $testSettingsPath
        if ($readSettings.releaseTag -ne 'v1.0.2' -or
            @(Get-ChildItem -LiteralPath $testRoot -Filter '*.tmp' -Force).Count -gt 0) {
            throw 'Installation state did not round-trip atomically in the isolated test directory.'
        }
        $testLogPath = Join-Path $testRoot 'setup.log'
        [System.IO.File]::WriteAllText($testLogPath, 'installer diagnostics')
        $testDiagnosticPath = Save-InstallerDiagnosticLog -LogPath $testLogPath
        if (-not $testDiagnosticPath -or
            (Test-Path -LiteralPath $testLogPath) -or
            [System.IO.File]::ReadAllText($testDiagnosticPath) -ne 'installer diagnostics') {
            throw 'Installer diagnostics were not retained outside the cleanup directory.'
        }

        $emptyInstallPath = Join-Path $testRoot 'empty-install'
        New-Item -ItemType Directory -Path $emptyInstallPath | Out-Null
        Assert-InstallDirectorySafe -InstallPath $emptyInstallPath
        $unrelatedPath = Join-Path $emptyInstallPath 'user-file.txt'
        [System.IO.File]::WriteAllText($unrelatedPath, 'preserve')
        $unrelatedFolderRejected = $false
        try {
            Assert-InstallDirectorySafe -InstallPath $emptyInstallPath
        } catch {
            $unrelatedFolderRejected = $true
        }
        if (-not $unrelatedFolderRejected -or
            [System.IO.File]::ReadAllText($unrelatedPath) -ne 'preserve') {
            throw 'Installer did not preserve/reject a non-empty unrelated installation folder.'
        }

        $fixturePath = Join-Path $testRoot 'payload.bin'
        $fixtureContent = 'SysCalculator installer test payload'
        [System.IO.File]::WriteAllText($fixturePath, $fixtureContent)
        $fixtureHash = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash
        $downloadDestination = Join-Path $testRoot 'verified-download.bin'
        $copyFixture = {
            param([string]$DownloadUrl, [string]$OutputPath)
            Copy-Item -LiteralPath $fixturePath -Destination $OutputPath
        }.GetNewClosure()
        Invoke-VerifiedDownload -Url 'https://github.com/Tenqo/SysCalculator/releases/download/v1.0.2/test.bin' `
            -Destination $downloadDestination -ExpectedSize (Get-Item $fixturePath).Length `
            -ExpectedDigest "sha256:$fixtureHash" -DownloadRequest $copyFixture
        if ((Get-FileHash -LiteralPath $downloadDestination -Algorithm SHA256).Hash -ine $fixtureHash) {
            throw 'Verified download self-test produced an unexpected file hash.'
        }

        $badDigestDestination = Join-Path $testRoot 'bad-digest.bin'
        $badDigestRejected = $false
        try {
            Invoke-VerifiedDownload -Url 'https://github.com/Tenqo/SysCalculator/releases/download/v1.0.2/test.bin' `
                -Destination $badDigestDestination -ExpectedSize (Get-Item $fixturePath).Length `
                -ExpectedDigest ('sha256:' + ('0' * 64)) -DownloadRequest $copyFixture
        } catch {
            $badDigestRejected = $_.Exception.Message -like '*SHA-256 checksum does not match*'
        }
        if (-not $badDigestRejected -or (Test-Path -LiteralPath $badDigestDestination)) {
            throw 'A failed SHA-256 verification left a destination file or was not rejected.'
        }

        $failedDestination = Join-Path $testRoot 'failed-download.bin'
        $partialFailure = {
            param([string]$DownloadUrl, [string]$OutputPath)
            [System.IO.File]::WriteAllText($OutputPath, 'partial download')
            throw 'simulated download failure'
        }
        $downloadFailureSurfaced = $false
        try {
            Invoke-VerifiedDownload -Url 'https://github.com/Tenqo/SysCalculator/releases/download/v1.0.2/test.bin' `
                -Destination $failedDestination -ExpectedSize (Get-Item $fixturePath).Length `
                -ExpectedDigest "sha256:$fixtureHash" -DownloadRequest $partialFailure
        } catch {
            $downloadFailureSurfaced = $_.Exception.Message -like '*simulated download failure*'
        }
        if (-not $downloadFailureSurfaced -or (Test-Path -LiteralPath $failedDestination) -or
            @(Get-ChildItem -LiteralPath $testRoot -Filter '*.partial' -Force).Count -gt 0) {
            throw 'A failed download was not surfaced or left a partial destination behind.'
        }

        $invalidUrlRejected = $false
        try {
            Invoke-VerifiedDownload -Url 'http://github.com/Tenqo/SysCalculator/test.bin' `
                -Destination (Join-Path $testRoot 'insecure-download.bin') `
                -ExpectedSize 1 -ExpectedDigest "sha256:$fixtureHash" -DownloadRequest $copyFixture
        } catch {
            $invalidUrlRejected = $_.Exception.Message -like '*trusted HTTPS GitHub URL*'
        }
        if (-not $invalidUrlRejected) {
            throw 'The verified downloader accepted a non-HTTPS release URL.'
        }

        $missingInstallRejected = $false
        try {
            Invoke-Uninstall -InstallPath $emptyInstallPath
        } catch {
            $missingInstallRejected = $_.Exception.Message -like '*SysCalculator.exe was not found*'
        }
        if (-not $missingInstallRejected) {
            throw 'Uninstall did not reject a missing installation without proceeding.'
        }

        $commandTestDirectory = Join-Path $testRoot 'cli'
        New-Item -ItemType Directory -Path $commandTestDirectory | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $commandTestDirectory 'SysCalculator.cmd'), 'launcher')
        [System.IO.File]::WriteAllText((Join-Path $commandTestDirectory 'Install-LatestRelease.ps1'), 'installer')
        $keepPath = Join-Path $commandTestDirectory 'keep.txt'
        [System.IO.File]::WriteAllText($keepPath, 'user data')
        Remove-CommandLineFiles -CommandDirectory $commandTestDirectory
        if (-not (Test-Path -LiteralPath $keepPath -PathType Leaf) -or
            (Test-Path -LiteralPath (Join-Path $commandTestDirectory 'SysCalculator.cmd')) -or
            (Test-Path -LiteralPath (Join-Path $commandTestDirectory 'Install-LatestRelease.ps1'))) {
            throw 'Uninstall command cleanup removed unrelated data or left a launcher file.'
        }
        if ((Test-Path -LiteralPath (Join-Path $testRoot 'does-not-exist')) -or
            (Test-Path -LiteralPath $keepPath -PathType Leaf) -eq $false) {
            throw 'Uninstall cleanup altered paths outside its command directory.'
        }

        $ownedCommandDirectory = Join-Path $testRoot 'owned-cli'
        New-Item -ItemType Directory -Path $ownedCommandDirectory | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $ownedCommandDirectory 'SysCalculator.cmd'), 'launcher')
        [System.IO.File]::WriteAllText((Join-Path $ownedCommandDirectory 'Install-LatestRelease.ps1'), 'installer')
        Remove-CommandLineFiles -CommandDirectory $ownedCommandDirectory
        if (Test-Path -LiteralPath $ownedCommandDirectory) {
            throw 'Uninstall cleanup did not remove an empty command folder after removing its own files.'
        }

        $selfDeleteDirectory = Join-Path $testRoot 'self-delete'
        New-Item -ItemType Directory -Path $selfDeleteDirectory | Out-Null
        $selfDeleteScript = Join-Path $selfDeleteDirectory 'Install-LatestRelease.ps1'
        $selfDeleteLauncher = Join-Path $selfDeleteDirectory 'SysCalculator.cmd'
        [System.IO.File]::WriteAllText($selfDeleteLauncher, 'launcher')
        [System.IO.File]::WriteAllText($selfDeleteScript, @'
$scriptPath = $PSCommandPath
$scriptDirectory = Split-Path -Parent $scriptPath
Remove-Item -LiteralPath (Join-Path $scriptDirectory 'SysCalculator.cmd') -Force
Remove-Item -LiteralPath $scriptPath -Force
if (Test-Path -LiteralPath $scriptPath) { exit 9 }
'@)
$powerShellExecutable = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
    $powerShellExecutable = Join-Path $PSHOME 'powershell.exe'
}
if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
    throw "Could not locate the current PowerShell executable under $PSHOME."
}
$selfDeleteProcess = Start-Process -FilePath $powerShellExecutable `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $selfDeleteScript)) `
            -Wait -PassThru -WindowStyle Hidden
        if ($selfDeleteProcess.ExitCode -ne 0 -or
            (Test-Path -LiteralPath $selfDeleteScript) -or
            (Test-Path -LiteralPath $selfDeleteLauncher)) {
            throw 'PowerShell could not remove the running command script and its launcher.'
        }

        $launcherTestDirectory = Join-Path $testRoot 'launcher'
        New-Item -ItemType Directory -Path $launcherTestDirectory | Out-Null
        $launcherScriptPath = Join-Path $launcherTestDirectory 'Install-LatestRelease.ps1'
        $launcherPath = Join-Path $launcherTestDirectory 'SysCalculator.cmd'
        $launcherOutputPath = Join-Path $testRoot 'launcher-output.txt'
        $launcherErrorPath = Join-Path $testRoot 'launcher-error.txt'
        Copy-Item -LiteralPath $PSCommandPath -Destination $launcherScriptPath
        [System.IO.File]::WriteAllText(
            $launcherPath,
            (Get-CommandLauncherContent),
            [System.Text.Encoding]::ASCII
        )
        $launcherProcess = Start-Process -FilePath $env:ComSpec `
            -ArgumentList @('/d', '/c', ('"{0}" help' -f $launcherPath)) `
            -Wait -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $launcherOutputPath `
            -RedirectStandardError $launcherErrorPath
        $launcherOutput = Get-Content -LiteralPath $launcherOutputPath -Raw
        if ($launcherProcess.ExitCode -ne 0 -or $launcherOutput -notmatch 'AVAILABLE COMMANDS') {
            throw 'The PATH command launcher did not forward a help command successfully.'
        }

        $invalidLauncherProcess = Start-Process -FilePath $env:ComSpec `
            -ArgumentList @('/d', '/c', ('"{0}" unknown-command' -f $launcherPath)) `
            -Wait -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $launcherOutputPath `
            -RedirectStandardError $launcherErrorPath
        $invalidLauncherOutput = Get-Content -LiteralPath $launcherOutputPath -Raw
        if ($invalidLauncherProcess.ExitCode -eq 0 -or
            $invalidLauncherOutput -notmatch 'Unknown command') {
            throw 'The command launcher did not reject an unknown command with a failing exit code.'
        }
    } finally {
        if ($testDiagnosticPath -and (Test-Path -LiteralPath $testDiagnosticPath -PathType Leaf)) {
            Remove-Item -LiteralPath $testDiagnosticPath -Force
        }
        if (Test-Path -LiteralPath $testRoot -PathType Container) {
            Remove-Item -LiteralPath $testRoot -Recurse -Force
        }
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

    $cancelDescription = Get-InstallerErrorDescription -ExitCode 2
    if ($cancelDescription -notlike '*canceled before installation began*') {
        throw 'Installer cancellation explanation self-test failed.'
    }
    if ((Get-InstallerErrorDescription -ExitCode 7) -notlike '*preparation stage failed*' -or
        (Get-InstallerErrorDescription -ExitCode 8) -notlike '*Windows is restarted*') {
        throw 'Installer preparation/restart error explanations are incorrect.'
    }

    Write-Host 'Installer self-tests passed: command parsing, download integrity, install detection, safe cleanup, architecture, path validation, setup arguments, and media separation.'
}

try {
    if ($SelfTest) {
        Invoke-InstallerSelfTest
    } elseif ($env:OS -ne 'Windows_NT') {
        throw 'SysCalculator can only be installed on Windows.'
    } elseif (-not [string]::IsNullOrWhiteSpace($Action)) {
        $resolvedAction = Resolve-InstallerCommand -InputValue $Action
        if (-not $resolvedAction) {
            Write-Status "Unknown command '$Action'. Type 'SysCalculator help' for available commands." -Level Warning
            Show-CommandHelp
            $script:ExitCode = 1
        } else {
            $commandLabel = if ($resolvedAction -eq 'exit') { 'exit' } else { "SysCalculator $resolvedAction" }
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
            $installedExecutable = Join-Path $settings.installPath 'SysCalculator.exe'
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
                        Write-Status "The app is current, but the SysCalculator command could not be registered: $($_.Exception.Message). You can still launch the app from $($settings.installPath)." -Level Warning
                    }
                    if ($decision -eq 'Current') {
                        Write-Status "SysCalculator is already up to date ($($latest.Release.tag_name))." -Level Success
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
                    Write-Status "Unknown command '$inputValue'. Type 'SysCalculator help' for available commands." -Level Warning
                    continue
                }

                $commandLabel = if ($command -eq 'exit') { 'exit' } else { "SysCalculator $command" }
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
    if (-not $SelfTest) {
        Clear-InstallerWorkDirectory
        Show-SessionSummary
    }
}

if ($script:ExitCode -ne 0) {
    exit $script:ExitCode
}
