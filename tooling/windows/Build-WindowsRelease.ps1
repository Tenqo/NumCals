param(
    [string]$SigningCertificateBase64 = $env:WINDOWS_SIGNING_CERTIFICATE_PFX,
    [System.Security.SecureString]$SigningCertificatePassword,
    [string]$TimestampServer = 'https://timestamp.digicert.com',
    [string]$OutputDirectory = 'dist',
    [switch]$InstallerScriptOnly,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Resolve-ReleaseOutputDirectory {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory) -or
        [System.IO.Path]::IsPathRooted($Directory)) {
        throw 'The output directory must be a relative path inside the project.'
    }

    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Directory))
    $projectRootPrefix = $projectRoot.TrimEnd([char[]]@('\', '/')) + '\'
    if (-not $resolvedPath.StartsWith(
            $projectRootPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'The output directory must remain inside the project.'
    }
    return $resolvedPath
}

$releasePath = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$outputPath = Resolve-ReleaseOutputDirectory -Directory $OutputDirectory
$portablePath = Join-Path $outputPath 'NumCals-portable.zip'
$installerScript = Join-Path $projectRoot 'packaging\windows\NumCals-Setup.iss'
$releaseInstallScript = Join-Path $PSScriptRoot 'installer\Install-LatestRelease.ps1'
$installerModuleDirectory = Join-Path $PSScriptRoot 'installer'
$checksumsPath = Join-Path $outputPath 'SHA256SUMS.txt'

function New-StandaloneInstaller {
    param([Parameter(Mandatory = $true)][string]$Destination)

    if (Test-Path -LiteralPath $Destination) {
        throw "Refusing to overwrite an existing standalone installer: $Destination"
    }

    $templateLines = [System.IO.File]::ReadAllLines($releaseInstallScript)
    $startIndexes = @(
        for ($index = 0; $index -lt $templateLines.Count; $index++) {
            if ($templateLines[$index] -ceq '# BEGIN INSTALLER MODULES') { $index }
        }
    )
    $endIndexes = @(
        for ($index = 0; $index -lt $templateLines.Count; $index++) {
            if ($templateLines[$index] -ceq '# END INSTALLER MODULES') { $index }
        }
    )
    if ($startIndexes.Count -ne 1 -or $endIndexes.Count -ne 1 -or
        $startIndexes[0] -ge $endIndexes[0]) {
        throw 'The installer source must contain one correctly ordered module marker pair.'
    }

    $moduleNames = @()
    for ($index = $startIndexes[0] + 1; $index -lt $endIndexes[0]; $index++) {
        $line = $templateLines[$index]
        if ($line -notmatch "^\s*\.\s*\(Join-Path \`$PSScriptRoot '([A-Za-z0-9_.-]+\.ps1)'\)\s*$") {
            throw "Unexpected installer module declaration: $line"
        }
        $moduleNames += $Matches[1]
    }
    if ($moduleNames.Count -eq 0 -or
        @($moduleNames | Select-Object -Unique).Count -ne $moduleNames.Count) {
        throw 'The installer source must list each source module exactly once.'
    }

    $bundle = New-Object System.Text.StringBuilder
    for ($index = 0; $index -lt $startIndexes[0]; $index++) {
        [void]$bundle.AppendLine($templateLines[$index])
    }
    $sourceFunctionNames = @()
    foreach ($moduleName in $moduleNames) {
        $modulePath = Join-Path $installerModuleDirectory $moduleName
        if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
            throw "Installer source module is missing: $modulePath"
        }

        $moduleContent = [System.IO.File]::ReadAllText($modulePath)
        [void]$bundle.Append($moduleContent)
        if (-not $moduleContent.EndsWith("`n")) {
            [void]$bundle.AppendLine()
        }

        $moduleTokens = $null
        $moduleErrors = $null
        $moduleAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $modulePath,
            [ref]$moduleTokens,
            [ref]$moduleErrors
        )
        if ($moduleErrors.Count -gt 0) {
            throw "Installer source module does not parse: $moduleName"
        }
        $sourceFunctionNames += @(
            $moduleAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true) | ForEach-Object { $_.Name }
        )
    }
    for ($index = $endIndexes[0] + 1; $index -lt $templateLines.Count; $index++) {
        [void]$bundle.AppendLine($templateLines[$index])
    }

    $bundleContent = $bundle.ToString()
    $encoding = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Destination, $bundleContent, $encoding)

    try {
        $bundleTokens = $null
        $bundleErrors = $null
        $bundleAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $Destination,
            [ref]$bundleTokens,
            [ref]$bundleErrors
        )
        if ($bundleErrors.Count -gt 0) {
            throw 'The generated standalone installer does not parse.'
        }

        $bundleFunctionNames = @(
            $bundleAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true) | ForEach-Object { $_.Name }
        )
        $expectedNames = @($sourceFunctionNames | Sort-Object)
        $actualNames = @($bundleFunctionNames | Sort-Object)
        if (($expectedNames -join '|') -cne ($actualNames -join '|')) {
            throw 'The generated installer does not contain every source function exactly once.'
        }
        if ($bundleContent -match "(?m)^\s*\.\s*\(Join-Path \`$PSScriptRoot ") {
            throw 'The generated installer still depends on source modules.'
        }

        $powershell = Get-Command powershell.exe -ErrorAction Stop
        $quotedDestination = '"' + $Destination.Replace('"', '""') + '"'
        $arguments = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File $quotedDestination -Action help"
        $process = Start-Process -FilePath $powershell.Source -ArgumentList $arguments `
            -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "The generated standalone installer smoke test failed with exit code $($process.ExitCode)."
        }
    } catch {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Get-SignToolPath {
    $kitsDirectory = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (-not (Test-Path -LiteralPath $kitsDirectory -PathType Container)) {
        throw 'Windows SDK SignTool was not found. Install the Windows SDK or build without signing credentials.'
    }

    $signTool = Get-ChildItem -LiteralPath $kitsDirectory -Filter signtool.exe -File -Recurse `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -match '\\x64$' } |
        Sort-Object -Property FullName -Descending |
        Select-Object -First 1
    if ($null -eq $signTool) {
        throw 'The Windows SDK x64 SignTool executable was not found.'
    }

    return $signTool.FullName
}

function Invoke-AuthenticodeSigning {
    param(
        [string]$SignTool,
        [string]$Thumbprint,
        [string]$FilePath,
        [string]$TimestampUrl
    )

    & $SignTool sign /fd SHA256 /tr $TimestampUrl /td SHA256 /s My /sha1 $Thumbprint $FilePath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool could not sign $([System.IO.Path]::GetFileName($FilePath))."
    }

    & $SignTool verify /pa /v $FilePath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool could not verify the signature on $([System.IO.Path]::GetFileName($FilePath))."
    }
}

function New-Sha256Manifest {
    param(
        [string[]]$AssetPaths,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        throw "Refusing to overwrite an existing checksum manifest: $Destination"
    }

    $assetNames = @($AssetPaths | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    if (@($assetNames | Select-Object -Unique).Count -ne $assetNames.Count) {
        throw 'Release assets must have unique file names for the checksum manifest.'
    }

    $lines = foreach ($assetPath in $AssetPaths) {
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
            throw "Release asset is missing and cannot be checksummed: $assetPath"
        }
        $name = [System.IO.Path]::GetFileName($assetPath)
        $hash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $name"
    }

    [System.IO.File]::WriteAllLines(
        $Destination,
        [string[]]$lines,
        [System.Text.Encoding]::ASCII
    )
}

function Test-Sha256Manifest {
    param(
        [string[]]$AssetPaths,
        [string]$ManifestPath
    )

    $lines = @(Get-Content -LiteralPath $ManifestPath)
    if ($lines.Count -ne $AssetPaths.Count) {
        throw 'The checksum manifest contains an unexpected number of assets.'
    }

    foreach ($assetPath in $AssetPaths) {
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
            throw "Release asset is missing: $assetPath"
        }

        $name = [System.IO.Path]::GetFileName($assetPath)
        $matchingLines = @(
            $lines | Where-Object { $_ -match "\s+$([regex]::Escape($name))$" }
        )
        if ($matchingLines.Count -ne 1 -or
            $matchingLines[0] -notmatch '^([a-fA-F0-9]{64})\s+(.+)$') {
            throw "The checksum manifest has no unique, valid entry for $name."
        }
        if ($Matches[2] -cne $name) {
            throw "The checksum manifest contains an invalid asset name for $name."
        }

        $actualHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash
        if ($actualHash -ine $Matches[1]) {
            throw "Checksum verification failed for $name."
        }
    }
}

function Invoke-BuildScriptSelfTest {
    $testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) `
        "NumCals-ReleaseSelfTest-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $testDirectory | Out-Null
    try {
        $assetOne = Join-Path $testDirectory 'setup.exe'
        $assetTwo = Join-Path $testDirectory 'portable.zip'
        $manifest = Join-Path $testDirectory 'SHA256SUMS.txt'
        [System.IO.File]::WriteAllText($assetOne, 'setup payload')
        [System.IO.File]::WriteAllText($assetTwo, 'portable payload')
        New-Sha256Manifest -AssetPaths @($assetOne, $assetTwo) -Destination $manifest

        $manifestLines = @(Get-Content -LiteralPath $manifest)
        if ($manifestLines.Count -ne 2) {
            throw 'Checksum manifest self-test produced an unexpected number of entries.'
        }
        foreach ($assetPath in @($assetOne, $assetTwo)) {
            $assetName = [System.IO.Path]::GetFileName($assetPath)
            $line = $manifestLines | Where-Object { $_ -match "\s+$([regex]::Escape($assetName))$" }
            if ($null -eq $line) {
                throw "Checksum manifest self-test is missing $assetName."
            }
            $expectedHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($line -notmatch "^$expectedHash\s+$([regex]::Escape($assetName))$") {
                throw "Checksum manifest self-test produced the wrong hash for $assetName."
            }
        }

        [System.IO.File]::AppendAllText($assetOne, ' altered')
        $modifiedAssetRejected = $false
        try {
            Test-Sha256Manifest -AssetPaths @($assetOne, $assetTwo) -ManifestPath $manifest
        } catch {
            $modifiedAssetRejected = $_.Exception.Message -like '*Checksum verification failed*'
        }
        if (-not $modifiedAssetRejected) {
            throw 'Checksum verification did not reject a modified release asset.'
        }

        $overwriteRejected = $false
        try {
            New-Sha256Manifest -AssetPaths @($assetOne) -Destination $manifest
        } catch {
            $overwriteRejected = $_.Exception.Message -like '*Refusing to overwrite*'
        }
        if (-not $overwriteRejected) {
            throw 'Checksum generation did not refuse to overwrite an existing manifest.'
        }

        $standaloneInstaller = Join-Path $testDirectory 'Install-LatestRelease.ps1'
        New-StandaloneInstaller -Destination $standaloneInstaller
        if (-not (Test-Path -LiteralPath $standaloneInstaller -PathType Leaf)) {
            throw 'The standalone installer self-test did not create its output.'
        }

        $originalCertificateBase64 = $SigningCertificateBase64
        $originalSecurePassword = $SigningCertificatePassword
        $originalCertificateEnvironment = [Environment]::GetEnvironmentVariable(
            'WINDOWS_SIGNING_CERTIFICATE_PFX',
            'Process'
        )
        $originalPasswordEnvironment = [Environment]::GetEnvironmentVariable(
            'WINDOWS_SIGNING_CERTIFICATE_PASSWORD',
            'Process'
        )
        try {
            $SigningCertificateBase64 = $null
            $SigningCertificatePassword = $null
            [Environment]::SetEnvironmentVariable('WINDOWS_SIGNING_CERTIFICATE_PFX', $null, 'Process')
            [Environment]::SetEnvironmentVariable(
                'WINDOWS_SIGNING_CERTIFICATE_PASSWORD',
                'self-test-only',
                'Process'
            )
            $partialSigningRejected = $false
            $partialSigningError = $null
            try {
                [void](Initialize-ReleaseSigning `
                    -CertificateBase64 $null `
                    -SecurePassword $null)
            } catch {
                $partialSigningError = $_.Exception.Message
                $partialSigningRejected = $partialSigningError -like '*Configure both*'
            }
            if (-not $partialSigningRejected) {
                throw "Partial signing configuration was not rejected as expected: $partialSigningError"
            }
            if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable(
                    'WINDOWS_SIGNING_CERTIFICATE_PASSWORD',
                    'Process'
                ))) {
                throw 'Partial signing configuration did not clear its environment password.'
            }
        } finally {
            $SigningCertificateBase64 = $originalCertificateBase64
            $SigningCertificatePassword = $originalSecurePassword
            [Environment]::SetEnvironmentVariable(
                'WINDOWS_SIGNING_CERTIFICATE_PFX',
                $originalCertificateEnvironment,
                'Process'
            )
            [Environment]::SetEnvironmentVariable(
                'WINDOWS_SIGNING_CERTIFICATE_PASSWORD',
                $originalPasswordEnvironment,
                'Process'
            )
        }

        $defaultOutputPath = Resolve-ReleaseOutputDirectory -Directory 'dist'
        if ($defaultOutputPath -ne [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'dist'))) {
            throw 'The default release output directory self-test failed.'
        }

        $outputPathEscapeRejected = $false
        try {
            [void](Resolve-ReleaseOutputDirectory -Directory '..\outside')
        } catch {
            $outputPathEscapeRejected = $_.Exception.Message -like '*inside the project*'
        }
        if (-not $outputPathEscapeRejected) {
            throw 'Release output directory validation allowed a path outside the project.'
        }

        Write-Host 'Release build self-tests passed: installer bundling, standalone execution, checksum integrity, overwrite protection, and output-path validation.'
    } finally {
        if (Test-Path -LiteralPath $testDirectory -PathType Container) {
            Remove-Item -LiteralPath $testDirectory -Recurse -Force
        }
    }
}

function Initialize-ReleaseSigning {
    param(
        [string]$CertificateBase64 = $SigningCertificateBase64,
        [System.Security.SecureString]$SecurePassword = $SigningCertificatePassword,
        [string]$TimestampUrl = $TimestampServer
    )

    $hasCertificate = -not [string]::IsNullOrWhiteSpace($CertificateBase64)
    $securePassword = $SecurePassword
    $passwordText = [Environment]::GetEnvironmentVariable(
        'WINDOWS_SIGNING_CERTIFICATE_PASSWORD',
        'Process'
    )
    try {
        if ($null -eq $securePassword -and
            -not [string]::IsNullOrWhiteSpace($passwordText)) {
            $securePassword = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
        }
    } finally {
        [Environment]::SetEnvironmentVariable(
            'WINDOWS_SIGNING_CERTIFICATE_PASSWORD',
            $null,
            'Process'
        )
        $passwordText = $null
    }

    $hasPassword = $false
    if ($null -ne $securePassword) {
        $hasPassword = $securePassword.Length -gt 0
    }
    if (-not $hasCertificate -and -not $hasPassword) {
        if ($null -ne $securePassword) {
            $securePassword.Dispose()
        }
        Write-Warning 'Windows Authenticode signing is not configured; release executables will be unsigned.'
        return $null
    }
    if (-not $hasCertificate -or -not $hasPassword) {
        if ($null -ne $securePassword) {
            $securePassword.Dispose()
        }
        throw 'Configure both WINDOWS_SIGNING_CERTIFICATE_PFX and WINDOWS_SIGNING_CERTIFICATE_PASSWORD, or leave both unset.'
    }

    $timestampUri = $null
    if (-not [Uri]::TryCreate($TimestampUrl, [UriKind]::Absolute, [ref]$timestampUri) -or
        $timestampUri.Scheme -ne 'https') {
        if ($null -ne $securePassword) {
            $securePassword.Dispose()
        }
        throw 'The Authenticode timestamp server must use HTTPS.'
    }

    $signingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) `
        "NumCals-Signing-$([guid]::NewGuid().ToString('N'))"
    $certificatePath = Join-Path $signingDirectory 'codesign.pfx'
    $certificateBytes = $null
    $importedCertificate = $null
    $newImportedThumbprints = @()

    try {
        New-Item -ItemType Directory -Path $signingDirectory | Out-Null
        try {
            $certificateBytes = [Convert]::FromBase64String($CertificateBase64)
        } catch {
            throw 'WINDOWS_SIGNING_CERTIFICATE_PFX is not valid base64.'
        }
        [System.IO.File]::WriteAllBytes($certificatePath, $certificateBytes)
        [Array]::Clear($certificateBytes, 0, $certificateBytes.Length)
        $certificateBytes = $null

        $existingThumbprints = @(
            Get-ChildItem -LiteralPath 'Cert:\CurrentUser\My' |
                ForEach-Object { $_.Thumbprint }
        )
        $pfxData = Get-PfxData -FilePath $certificatePath -Password $securePassword
        $pfxThumbprints = @(
            @($pfxData.EndEntityCertificates) + @($pfxData.OtherCertificates) |
                ForEach-Object { $_.Thumbprint } |
                Select-Object -Unique
        )
        $existingSigningCertificate = @(
            @($pfxData.EndEntityCertificates) |
                Where-Object { $existingThumbprints -contains $_.Thumbprint }
        )
        if ($existingSigningCertificate.Count -gt 0) {
            throw 'The PFX signing certificate already exists in the current-user store. Use an isolated build runner to avoid changing an existing certificate.'
        }
        $newImportedThumbprints = @(
            $pfxThumbprints | Where-Object { $existingThumbprints -notcontains $_ }
        )
        $certificates = @(Import-PfxCertificate -FilePath $certificatePath `
            -CertStoreLocation 'Cert:\CurrentUser\My' -Password $securePassword)
        $importedCertificate = $certificates |
            Where-Object {
                $_.HasPrivateKey -and
                $_.NotBefore -le (Get-Date) -and
                $_.NotAfter -gt (Get-Date) -and
                ($_.EnhancedKeyUsageList.ObjectId.Value -contains '1.3.6.1.5.5.7.3.3')
            } |
            Select-Object -First 1
        if ($null -eq $importedCertificate) {
            throw 'The signing certificate must be valid, include its private key, and allow code signing.'
        }

        $securePassword.Dispose()
        $securePassword = $null
        Remove-Item -LiteralPath $certificatePath -Force
        $signTool = Get-SignToolPath
        Write-Host "Authenticode signing enabled with certificate $($importedCertificate.Thumbprint)."

        return [pscustomobject]@{
            Directory = $signingDirectory
            Certificate = $importedCertificate
            ImportedThumbprints = $newImportedThumbprints
            SignTool = $signTool
            TimestampUrl = $TimestampUrl
        }
    } catch {
        foreach ($thumbprint in $newImportedThumbprints) {
            Remove-Item -LiteralPath "Cert:\CurrentUser\My\$thumbprint" `
                -Force -ErrorAction SilentlyContinue
        }
        if ($securePassword) {
            $securePassword.Dispose()
        }
        if ($certificateBytes) {
            [Array]::Clear($certificateBytes, 0, $certificateBytes.Length)
        }
        if (Test-Path -LiteralPath $signingDirectory -PathType Container) {
            Remove-Item -LiteralPath $signingDirectory -Recurse -Force
        }
        throw
    }
}

if ($SelfTest) {
    Invoke-BuildScriptSelfTest
    return
}

if ($InstallerScriptOnly) {
    if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
        New-Item -ItemType Directory -Path $outputPath | Out-Null
    }

    $standaloneInstaller = Join-Path $outputPath 'Install-LatestRelease.ps1'
    New-StandaloneInstaller -Destination $standaloneInstaller
    Write-Output "Standalone release installer created: $standaloneInstaller"
    return
}

Push-Location $projectRoot
$signing = $null
$stagingPath = $null
$publishedOutputs = @()
$buildSucceeded = $false
try {
    $expectedOutputs = @(
        (Join-Path $outputPath 'NumCals-Setup.exe'),
        $portablePath,
        (Join-Path $outputPath 'Install-LatestRelease.ps1'),
        $checksumsPath
    )
    $existingOutputs = @($expectedOutputs | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingOutputs.Count -gt 0) {
        throw "Refusing to overwrite existing release output(s): $($existingOutputs -join ', '). Choose an empty output directory or move them out before building."
    }

    $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($null -eq $compilerCommand) {
        $innoSetupPaths = @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
            (Join-Path $env:LOCALAPPDATA 'Inno Setup 6\ISCC.exe'),
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
    $version = $versionMatch.Matches[0].Groups[1].Value

    $signing = Initialize-ReleaseSigning

    flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get --enforce-lockfile failed.'
    }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows release build failed.'
    }

    if (-not (Test-Path -LiteralPath (Join-Path $releasePath 'NumCals.exe'))) {
        throw "The Windows app was not found at $releasePath."
    }
    $applicationExecutable = Join-Path $releasePath 'NumCals.exe'
    $applicationInformation = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($applicationExecutable)
    if ($applicationInformation.ProductName -ine 'NumCals' -or
        $applicationInformation.FileVersion -notmatch "^$([regex]::Escape($version))(\+\d+|\.\d+)?$") {
        throw "The built NumCals.exe version does not match pubspec.yaml version $version."
    }

    if ($signing) {
        Invoke-AuthenticodeSigning -SignTool $signing.SignTool `
            -Thumbprint $signing.Certificate.Thumbprint `
            -FilePath $applicationExecutable `
            -TimestampUrl $signing.TimestampUrl
    }

    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    $stagingPath = Join-Path $outputPath `
        ".NumCals-Release-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagingPath | Out-Null

    Compress-Archive -Path (Join-Path $releasePath '*') `
        -DestinationPath (Join-Path $stagingPath 'NumCals-portable.zip')

    $compilerArguments = @(
        "/DAppSource=$releasePath",
        "/DAppVersion=$version",
        "/O$stagingPath",
        '/FNumCals-Setup',
        $installerScript
    )
    & $compilerPath @compilerArguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $stagingPath 'NumCals-Setup.exe') -PathType Leaf)) {
        throw 'Inno Setup could not create the Windows setup executable.'
    }

    $setupExecutable = Join-Path $stagingPath 'NumCals-Setup.exe'
    if ($signing) {
        Invoke-AuthenticodeSigning -SignTool $signing.SignTool `
            -Thumbprint $signing.Certificate.Thumbprint `
            -FilePath $setupExecutable `
            -TimestampUrl $signing.TimestampUrl
    }

    $stagedInstallScript = Join-Path $stagingPath 'Install-LatestRelease.ps1'
    New-StandaloneInstaller -Destination $stagedInstallScript

    $stagedPortable = Join-Path $stagingPath 'NumCals-portable.zip'
    $stagedChecksums = Join-Path $stagingPath 'SHA256SUMS.txt'
    New-Sha256Manifest -AssetPaths @(
        $setupExecutable,
        $stagedPortable,
        $stagedInstallScript
    ) -Destination $stagedChecksums
    Test-Sha256Manifest -AssetPaths @(
        $setupExecutable,
        $stagedPortable,
        $stagedInstallScript
    ) -ManifestPath $stagedChecksums

    $outputsToPublish = @(
        @{ Source = $setupExecutable; Destination = (Join-Path $outputPath 'NumCals-Setup.exe') },
        @{ Source = $stagedPortable; Destination = $portablePath },
        @{ Source = $stagedInstallScript; Destination = (Join-Path $outputPath 'Install-LatestRelease.ps1') },
        @{ Source = $stagedChecksums; Destination = $checksumsPath }
    )
    foreach ($output in $outputsToPublish) {
        Move-Item -LiteralPath $output.Source -Destination $output.Destination
        $publishedOutputs += $output.Destination
    }

    Test-Sha256Manifest -AssetPaths @(
        (Join-Path $outputPath 'NumCals-Setup.exe'),
        $portablePath,
        (Join-Path $outputPath 'Install-LatestRelease.ps1')
    ) -ManifestPath $checksumsPath
    $buildSucceeded = $true

    Write-Output "Windows setup created: $(Join-Path $outputPath 'NumCals-Setup.exe')"
    Write-Output "Portable app created: $portablePath"
    Write-Output "Release installer created: $(Join-Path $outputPath 'Install-LatestRelease.ps1')"
    Write-Output "Release checksums created: $checksumsPath"
    if ($signing) {
        Write-Output 'Windows setup and application executables were signed and verified.'
    }
}
finally {
    if (-not $buildSucceeded) {
        foreach ($publishedOutput in $publishedOutputs) {
            if (Test-Path -LiteralPath $publishedOutput -PathType Leaf) {
                Remove-Item -LiteralPath $publishedOutput -Force
            }
        }
    }
    if ($stagingPath -and (Test-Path -LiteralPath $stagingPath -PathType Container)) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
    if ($signing) {
        foreach ($thumbprint in $signing.ImportedThumbprints) {
            Remove-Item -LiteralPath "Cert:\CurrentUser\My\$thumbprint" `
                -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $signing.Directory -PathType Container) {
            Remove-Item -LiteralPath $signing.Directory -Recurse -Force
        }
    }
    Pop-Location
}
