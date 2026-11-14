param(
    [string]$SigningCertificateBase64 = $env:WINDOWS_SIGNING_CERTIFICATE_PFX,
    [System.Security.SecureString]$SigningCertificatePassword,
    [string]$TimestampServer = 'https://timestamp.digicert.com',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releasePath = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$outputPath = Join-Path $projectRoot 'dist'
$portablePath = Join-Path $outputPath 'SysCalculator-portable.zip'
$installerScript = Join-Path $projectRoot 'packaging\windows\SysCalculator-Setup.iss'
$releaseInstallScript = Join-Path $PSScriptRoot 'Install-LatestRelease.ps1'
$checksumsPath = Join-Path $outputPath 'SHA256SUMS.txt'

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

function Invoke-BuildScriptSelfTest {
    $testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) `
        "SysCalculator-ReleaseSelfTest-$([guid]::NewGuid().ToString('N'))"
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

        $overwriteRejected = $false
        try {
            New-Sha256Manifest -AssetPaths @($assetOne) -Destination $manifest
        } catch {
            $overwriteRejected = $_.Exception.Message -like '*Refusing to overwrite*'
        }
        if (-not $overwriteRejected) {
            throw 'Checksum generation did not refuse to overwrite an existing manifest.'
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

        Write-Host 'Release build self-tests passed: SHA-256 manifest generation and overwrite protection.'
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
        "SysCalculator-Signing-$([guid]::NewGuid().ToString('N'))"
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

Push-Location $projectRoot
$signing = $null
try {
    $expectedOutputs = @(
        (Join-Path $outputPath 'SysCalculator-Setup.exe'),
        $portablePath,
        (Join-Path $outputPath 'Install-LatestRelease.ps1'),
        $checksumsPath
    )
    $existingOutputs = @($expectedOutputs | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingOutputs.Count -gt 0) {
        throw "Refusing to overwrite existing release output(s): $($existingOutputs -join ', '). Move them out of dist before building."
    }

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
    $version = $versionMatch.Matches[0].Groups[1].Value

    $signing = Initialize-ReleaseSigning

    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed.'
    }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows release build failed.'
    }

    if (-not (Test-Path -LiteralPath (Join-Path $releasePath 'SysCalculator.exe'))) {
        throw "The Windows app was not found at $releasePath."
    }
    $applicationExecutable = Join-Path $releasePath 'SysCalculator.exe'
    $applicationInformation = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($applicationExecutable)
    if ($applicationInformation.ProductName -ine 'SysCalculator' -or
        $applicationInformation.FileVersion -notmatch "^$([regex]::Escape($version))(\+\d+|\.\d+)?$") {
        throw "The built SysCalculator.exe version does not match pubspec.yaml version $version."
    }

    if ($signing) {
        Invoke-AuthenticodeSigning -SignTool $signing.SignTool `
            -Thumbprint $signing.Certificate.Thumbprint `
            -FilePath $applicationExecutable `
            -TimestampUrl $signing.TimestampUrl
    }

    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    Compress-Archive -Path (Join-Path $releasePath '*') -DestinationPath $portablePath

    $compilerArguments = @(
        "/DAppSource=$releasePath",
        "/DAppVersion=$version",
        "/O$outputPath",
        '/FSysCalculator-Setup',
        $installerScript
    )
    & $compilerPath @compilerArguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $outputPath 'SysCalculator-Setup.exe') -PathType Leaf)) {
        throw 'Inno Setup could not create the Windows setup executable.'
    }

    $setupExecutable = Join-Path $outputPath 'SysCalculator-Setup.exe'
    if ($signing) {
        Invoke-AuthenticodeSigning -SignTool $signing.SignTool `
            -Thumbprint $signing.Certificate.Thumbprint `
            -FilePath $setupExecutable `
            -TimestampUrl $signing.TimestampUrl
    }

    Copy-Item -LiteralPath $releaseInstallScript -Destination $outputPath

    New-Sha256Manifest -AssetPaths @(
        $setupExecutable,
        $portablePath,
        (Join-Path $outputPath 'Install-LatestRelease.ps1')
    ) -Destination $checksumsPath

    Write-Output "Windows setup created: $(Join-Path $outputPath 'SysCalculator-Setup.exe')"
    Write-Output "Portable app created: $portablePath"
    Write-Output "Release installer created: $(Join-Path $outputPath 'Install-LatestRelease.ps1')"
    Write-Output "Release checksums created: $checksumsPath"
    if ($signing) {
        Write-Output 'Windows setup and application executables were signed and verified.'
    }
}
finally {
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
