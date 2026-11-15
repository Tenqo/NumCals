param([string]$InstallerPath)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($InstallerPath)) {
    $installerScript = Join-Path $projectRoot 'tooling\windows\installer\Install-LatestRelease.ps1'
} else {
    $installerScript = (Resolve-Path -LiteralPath $InstallerPath).Path
}
. $installerScript -LibraryOnly

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    "NumCals-InstallerTests-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testRoot | Out-Null
$assertionCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
    $script:assertionCount++
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)

    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', received '$Actual'."
    }
    $script:assertionCount++
}

function Assert-ThrowsLike {
    param(
        [scriptblock]$Action,
        [string]$ExpectedMessage,
        [string]$TestName
    )

    $actualMessage = $null
    try {
        & $Action
    } catch {
        $actualMessage = $_.Exception.Message
    }
    if ($null -eq $actualMessage -or $actualMessage -notlike $ExpectedMessage) {
        throw "$TestName did not fail as expected. Actual error: $actualMessage"
    }
    $script:assertionCount++
}

try {
    $choices = @(
        [pscustomobject]@{ value = 'yes'; label = 'Yes' },
        [pscustomobject]@{ value = 'no'; label = 'No' },
        [pscustomobject]@{ value = 'skip'; label = 'Skip' }
    )
    Assert-Equal (Resolve-Choice -InputValue '1' -Options $choices) 'yes' 'Numeric choices'
    Assert-Equal (Resolve-Choice -InputValue 'SKIP' -Options $choices) 'skip' 'Named choices'
    Assert-True ($null -eq (Resolve-Choice -InputValue '4' -Options $choices)) `
        'Out-of-range choices must be rejected.'

    $validCommands = @{
        'nUmCaLs uPdAtE' = 'update'
        'NumCals UPGRADE' = 'upgrade'
        'NUMCALS REMOVE' = 'remove'
        '1' = 'update'
        '2' = 'upgrade'
        '3' = 'remove'
        '4' = 'help'
        '5' = 'exit'
        'rEmOvE' = 'remove'
        'uPdAtE' = 'update'
        'upGRADE' = 'upgrade'
        'hElP' = 'help'
        'EXIT' = 'exit'
    }
    foreach ($inputValue in $validCommands.Keys) {
        Assert-Equal (Resolve-InstallerCommand -InputValue $inputValue) `
            $validCommands[$inputValue] "Command '$inputValue'"
    }
    Assert-True ($null -eq (Resolve-InstallerCommand -InputValue 'NumCals remove/install')) `
        'Compound command injection must not be accepted.'

    $launcher = Get-CommandLauncherContent
    Assert-True ($launcher.Contains('-NoProfile -File') -and
        -not $launcher.Contains('-ExecutionPolicy')) `
        'The installed command must not bypass the execution policy.'
    Assert-Equal (Get-StatusStyle -Level Success).Color ([ConsoleColor]::Green) `
        'Success status color'
    Assert-Equal (Get-StatusStyle -Level Warning).Color ([ConsoleColor]::Yellow) `
        'Warning status color'
    Assert-Equal (Get-StatusStyle -Level Error).Color ([ConsoleColor]::Red) `
        'Error status color'

    Assert-Equal (Get-OperatingSystemArchitecture -ProcessArchitecture 'AMD64' `
        -Is64BitOperatingSystem $true) 'x64' 'x64 detection'
    Assert-Equal (Get-OperatingSystemArchitecture -ProcessArchitecture 'x86' `
        -NativeArchitecture 'ARM64' -Is64BitOperatingSystem $true) 'ARM64' 'ARM64 detection'
    Assert-Equal (Get-OperatingSystemArchitecture -ProcessArchitecture 'x86' `
        -Is64BitOperatingSystem $false) 'x86' 'x86 detection'
    Assert-ThrowsLike { Assert-SupportedArchitecture -Architecture 'x86' } `
        '*64-bit Windows*' 'Unsupported architecture'

    Assert-Equal (Get-InstallationDecision -ExecutableExists $false `
        -InstalledReleaseTag '' -LatestReleaseTag 'v1.0.2') 'Install' 'New installation'
    Assert-Equal (Get-InstallationDecision -ExecutableExists $true `
        -InstalledReleaseTag 'v1.0.2' -LatestReleaseTag 'v1.0.2') 'Current' 'Current installation'
    Assert-Equal (Get-InstallationDecision -ExecutableExists $true `
        -InstalledReleaseTag 'v1.0.3' -LatestReleaseTag 'v1.0.2') `
        'NewerInstalled' 'Prevent downgrade'
    Assert-Equal (Get-InstallationDecision -ExecutableExists $true `
        -InstalledReleaseTag 'v1.0.1' -LatestReleaseTag 'v1.0.2') 'Update' 'Upgrade decision'
    Assert-Equal (Get-InstallationDecision -ExecutableExists $true `
        -InstalledReleaseTag '' -LatestReleaseTag 'v1.0.2') `
        'UnknownVersion' 'Unknown installed version'

    $installPath = Join-Path $testRoot 'NumCals café'
    Assert-Equal (Resolve-InstallPath -InputPath $installPath) `
        ([System.IO.Path]::GetFullPath($installPath)) 'Unicode installation path'
    Assert-ThrowsLike { Resolve-InstallPath -InputPath 'C:\Sys"Calculator' } `
        '*unsupported characters*' 'Quoted installation path'
    Assert-ThrowsLike { Resolve-InstallPath -InputPath 'C:\' } `
        '*drive root*' 'Drive-root installation path'

    $silentArguments = New-SetupArgumentString `
        -InstallPath 'C:\Users\Test User\NumCals' `
        -LogPath 'C:\Temp\setup.log' -ShortcutChoice 'skip'
    Assert-True ($silentArguments -match '/VERYSILENT' -and
        $silentArguments -match '/TASKS="!desktopicon"') `
        'Silent setup arguments or shortcut choice are incorrect.'
    $shortcutArguments = New-SetupArgumentString `
        -InstallPath 'C:\Users\Test User\NumCals' `
        -LogPath 'C:\Temp\setup.log' -ShortcutChoice 'yes'
    Assert-True ($shortcutArguments -match '/TASKS="desktopicon"') `
        'Desktop shortcut setup argument is incorrect.'

    $settingsPath = Join-Path $testRoot 'install-state.json'
    $settings = @{
        repository = 'Tenqo/NumCals'
        installPath = $installPath
        releaseTag = 'v1.0.2'
    }
    Write-PersistedSettings -Settings $settings -Path $settingsPath
    $readSettings = Read-PersistedSettings -Path $settingsPath
    Assert-Equal $readSettings.releaseTag 'v1.0.2' 'Persisted settings'
    Assert-Equal (@(Get-ChildItem -LiteralPath $testRoot -Filter '*.tmp' -Force).Count) 0 `
        'Atomic settings cleanup'

    $emptyInstallPath = Join-Path $testRoot 'empty-install'
    New-Item -ItemType Directory -Path $emptyInstallPath | Out-Null
    Assert-True ($null -eq (Assert-InstallDirectorySafe -InstallPath $emptyInstallPath)) `
        'An empty installation directory should be accepted.'
    $unrelatedPath = Join-Path $emptyInstallPath 'user-file.txt'
    [System.IO.File]::WriteAllText($unrelatedPath, 'preserve')
    Assert-ThrowsLike { Assert-InstallDirectorySafe -InstallPath $emptyInstallPath } `
        '*not empty*' 'Non-empty unrelated installation directory'
    Assert-Equal ([System.IO.File]::ReadAllText($unrelatedPath)) 'preserve' `
        'Preserve unrelated install-directory file'

    $fixturePath = Join-Path $testRoot 'payload.bin'
    [System.IO.File]::WriteAllText($fixturePath, 'NumCals installer test payload')
    $fixtureSize = (Get-Item -LiteralPath $fixturePath).Length
    $fixtureHash = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash
    $copyFixture = {
        param([string]$DownloadUrl, [string]$OutputPath)
        Copy-Item -LiteralPath $fixturePath -Destination $OutputPath
    }.GetNewClosure()
    $validDownload = Join-Path $testRoot 'verified-download.bin'
    Invoke-VerifiedDownload `
        -Url 'https://github.com/Tenqo/NumCals/releases/download/v1.0.2/test.bin' `
        -Destination $validDownload -ExpectedSize $fixtureSize `
        -ExpectedDigest "sha256:$fixtureHash" -DownloadRequest $copyFixture
    Assert-Equal (Get-FileHash -LiteralPath $validDownload -Algorithm SHA256).Hash `
        $fixtureHash 'Verified download digest'

    $badDigestDestination = Join-Path $testRoot 'bad-digest.bin'
    Assert-ThrowsLike {
        Invoke-VerifiedDownload `
            -Url 'https://github.com/Tenqo/NumCals/releases/download/v1.0.2/test.bin' `
            -Destination $badDigestDestination -ExpectedSize $fixtureSize `
            -ExpectedDigest ('sha256:' + ('0' * 64)) -DownloadRequest $copyFixture
    } '*SHA-256 checksum does not match*' 'Invalid download digest'
    Assert-True (-not (Test-Path -LiteralPath $badDigestDestination)) `
        'A bad digest must not leave a destination file.'

    $downloadCalls = New-Object System.Collections.ArrayList
    $countingDownload = {
        param([string]$DownloadUrl, [string]$OutputPath)
        [void]$downloadCalls.Add(1)
    }.GetNewClosure()
    Assert-ThrowsLike {
        Invoke-VerifiedDownload `
            -Url 'https://github.com/Tenqo/NumCals/releases/download/v1.0.2/test.bin' `
            -Destination (Join-Path $testRoot 'oversize.bin') `
            -ExpectedSize (100MB + 1) -ExpectedDigest "sha256:$fixtureHash" `
            -DownloadRequest $countingDownload
    } '*valid asset size*' 'Oversized asset metadata'
    Assert-Equal $downloadCalls.Count 0 'Reject oversized metadata before download'

    $failedDestination = Join-Path $testRoot 'failed-download.bin'
    $partialFailure = {
        param([string]$DownloadUrl, [string]$OutputPath)
        [System.IO.File]::WriteAllText($OutputPath, 'partial download')
        throw 'simulated download failure'
    }
    Assert-ThrowsLike {
        Invoke-VerifiedDownload `
            -Url 'https://github.com/Tenqo/NumCals/releases/download/v1.0.2/test.bin' `
            -Destination $failedDestination -ExpectedSize $fixtureSize `
            -ExpectedDigest "sha256:$fixtureHash" -DownloadRequest $partialFailure
    } '*simulated download failure*' 'Failed download'
    Assert-True (-not (Test-Path -LiteralPath $failedDestination) -and
        @(Get-ChildItem -LiteralPath $testRoot -Filter '*.partial' -Force).Count -eq 0) `
        'Failed downloads must remove partial files.'

    Assert-ThrowsLike {
        Invoke-VerifiedDownload -Url 'http://github.com/Tenqo/NumCals/test.bin' `
            -Destination (Join-Path $testRoot 'insecure-download.bin') `
            -ExpectedSize 1 -ExpectedDigest "sha256:$fixtureHash" `
            -DownloadRequest $copyFixture
    } '*trusted HTTPS GitHub URL*' 'Non-HTTPS asset URL'
    Assert-ThrowsLike {
        Invoke-VerifiedDownload `
            -Url 'https://github.com/Tenqo/NumCals/releases/download/v1.0.2/test.bin' `
            -Destination $validDownload -ExpectedSize $fixtureSize `
            -ExpectedDigest "sha256:$fixtureHash" -DownloadRequest $copyFixture
    } '*Refusing to overwrite*' 'Existing download destination'

    $commandTestDirectory = Join-Path $testRoot 'cli'
    New-Item -ItemType Directory -Path $commandTestDirectory | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $commandTestDirectory 'NumCals.cmd'), 'launcher')
    [System.IO.File]::WriteAllText(
        (Join-Path $commandTestDirectory 'Install-LatestRelease.ps1'),
        'installer'
    )
    $keepPath = Join-Path $commandTestDirectory 'keep.txt'
    [System.IO.File]::WriteAllText($keepPath, 'user data')
    Remove-CommandLineFiles -CommandDirectory $commandTestDirectory
    Assert-True ((Test-Path -LiteralPath $keepPath -PathType Leaf) -and
        -not (Test-Path -LiteralPath (Join-Path $commandTestDirectory 'NumCals.cmd')) -and
        -not (Test-Path -LiteralPath (Join-Path $commandTestDirectory 'Install-LatestRelease.ps1'))) `
        'Command cleanup must remove only NumCals launcher files.'
    $preservedCommandData = [System.IO.File]::ReadAllText($keepPath)
    Assert-Equal $preservedCommandData 'user data' `
        'Preserve unrelated command-folder data'

    $ownedCommandDirectory = Join-Path $testRoot 'owned-cli'
    New-Item -ItemType Directory -Path $ownedCommandDirectory | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $ownedCommandDirectory 'NumCals.cmd'), 'launcher')
    [System.IO.File]::WriteAllText(
        (Join-Path $ownedCommandDirectory 'Install-LatestRelease.ps1'),
        'installer'
    )
    Remove-CommandLineFiles -CommandDirectory $ownedCommandDirectory
    Assert-True (-not (Test-Path -LiteralPath $ownedCommandDirectory)) `
        'Remove the empty command directory after deleting owned files.'

    $missingInstallPath = Join-Path $testRoot 'missing-install'
    New-Item -ItemType Directory -Path $missingInstallPath | Out-Null
    Assert-ThrowsLike {
        Invoke-Uninstall -InstallPath $missingInstallPath
    } '*NumCals.exe was not found*' 'Reject unrecognized uninstall path'

    $installFailureDirectory = Join-Path $testRoot 'failed-install'
    $testInstallWorkDirectory = Join-Path $testRoot 'install-work'
    $script:WorkDirectory = $testInstallWorkDirectory
    $releaseProvider = {
        [pscustomobject]@{
            Release = [pscustomobject]@{ tag_name = 'v1.0.2' }
            Asset = [pscustomobject]@{
                browser_download_url = 'https://github.com/Tenqo/NumCals/releases/download/v1.0.2/NumCals-Setup.exe'
                size = $fixtureSize
                digest = "sha256:$fixtureHash"
            }
        }
    }.GetNewClosure()
    $failedProcess = [pscustomobject]@{ ExitCode = 4 }
    $failedProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {}
    $failedProcess | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
    $setupProcessLauncher = { param($Path, $Arguments) $failedProcess }.GetNewClosure()
    Assert-ThrowsLike {
        Invoke-SetupInstall -Settings @{
            installPath = $installFailureDirectory
            shortcutChoice = 'skip'
            releaseTag = 'v1.0.1'
        } -ReleaseProvider $releaseProvider -DownloadRequest $copyFixture `
            -SetupProcessLauncher $setupProcessLauncher
    } '*Installation failed with code 4*' 'Failed setup process'
    Clear-InstallerWorkDirectory
    Assert-True (-not (Test-Path -LiteralPath $testInstallWorkDirectory)) `
        'Failed installation must clean temporary setup files.'

    Write-Host "PASS: $assertionCount isolated Windows installer assertions."
} finally {
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
