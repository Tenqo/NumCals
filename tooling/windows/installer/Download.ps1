function Invoke-VerifiedDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [long]$ExpectedSize,
        [string]$ExpectedDigest,
        [scriptblock]$DownloadRequest
    )

    $downloadUri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$downloadUri) -or
        $downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ine 'github.com') {
        throw 'The release download URL is not a trusted HTTPS GitHub URL.'
    }
    if ($ExpectedSize -le 0 -or $ExpectedSize -gt 100MB) {
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
            if ($DownloadRequest) {
                & $DownloadRequest $Url $partialPath
            } else {
                Save-BoundedHttpResponse -Url $Url -Destination $partialPath `
                    -MaximumBytes $ExpectedSize -Accept 'application/octet-stream' `
                    -AllowedRedirectHosts @(
                        'github.com',
                        'release-assets.githubusercontent.com',
                        'objects.githubusercontent.com'
                    ) | Out-Null
            }
        } catch {
            throw "Release download failed. No installer was run and the partial download will be removed. Check internet/proxy access to GitHub and try the command again. Details: $($_.Exception.Message)"
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

        [System.IO.File]::Move($partialPath, $Destination)
    } finally {
        if (Test-Path -LiteralPath $partialPath -PathType Leaf) {
            Remove-Item -LiteralPath $partialPath -Force
        }
    }
}
