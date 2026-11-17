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
        Write-Status 'If installation did not complete or NumCals is missing, review the red errors above.' -Level Warning
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
    return "@echo off`r`npowershell.exe -NoProfile -File `"%~dp0Install-LatestRelease.ps1`" -Action `"%*`"`r`n"
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

    $launcherPath = Join-Path $script:CommandDirectory 'NumCals.cmd'
    [System.IO.File]::WriteAllText(
        $launcherPath,
        (Get-CommandLauncherContent),
        [System.Text.Encoding]::ASCII
    )
    Add-CommandDirectoryToPath
    Write-Status 'PowerShell command registered. Open a new PowerShell window to use NumCals.' -Level Success
}

function Remove-CommandLineFiles {
    param([string]$CommandDirectory)

    $filesToRemove = @('NumCals.cmd', 'Install-LatestRelease.ps1')

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

function Show-CommandHelp {
    Write-Host ''
    Write-Host '  AVAILABLE COMMANDS' -ForegroundColor Cyan
    Write-Host '  [1] NumCals update     Install only when a newer release is available.' -ForegroundColor Gray
    Write-Host '  [2] NumCals upgrade    Reinstall the latest release.' -ForegroundColor Gray
    Write-Host '  [3] NumCals remove     Confirm and uninstall NumCals.' -ForegroundColor Gray
    Write-Host '  [4] NumCals help       Show this help.' -ForegroundColor Gray
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

    if ($tokens[0] -ieq 'NumCals') {
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
        "NumCals-setup-$([guid]::NewGuid().ToString('N')).log"
    Move-Item -LiteralPath $LogPath -Destination $diagnosticPath
    return $diagnosticPath
}
