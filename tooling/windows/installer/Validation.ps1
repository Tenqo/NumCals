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
        throw "NumCals requires 64-bit Windows (x64 or ARM64). Detected architecture: $Architecture."
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
        throw "NumCals.exe was not found at $ExecutablePath."
    }

    $fileInformation = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExecutablePath)
    if ($fileInformation.ProductName -ine 'NumCals') {
        throw "The executable at $ExecutablePath is not identified as the NumCals app."
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

    $installedExecutable = Join-Path $InstallPath 'NumCals.exe'
    if (Test-Path -LiteralPath $installedExecutable -PathType Leaf) {
        [void](Assert-InstalledExecutable -ExecutablePath $installedExecutable)
        return
    }

    if (@(Get-ChildItem -LiteralPath $InstallPath -Force).Count -gt 0) {
        throw "The selected folder is not empty and does not contain NumCals.exe: $InstallPath. Choose an empty folder to avoid overwriting unrelated files."
    }
}
