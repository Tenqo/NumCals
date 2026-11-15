if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Repository must use the owner/repository format, for example 'Tenqo/NumCals'."
}

$script:RepositoryName = $Repository
$script:WorkDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "NumCals-Install-$([guid]::NewGuid().ToString('N'))"
$script:SettingsPath = Join-Path $env:LOCALAPPDATA 'Tenqo Digital\NumCals\install-state.json'
$script:CommandDirectory = Join-Path (Split-Path -Parent $script:SettingsPath) 'cli'
$script:CommandScriptPath = Join-Path $script:CommandDirectory 'Install-LatestRelease.ps1'
$script:HadErrors = $false
$script:HadWarnings = $false
$script:InstallationCompleted = $false
$script:ExitCode = 0

function Read-InstallSettings {
    $defaultPath = Join-Path $env:LOCALAPPDATA 'Programs\NumCals'
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
