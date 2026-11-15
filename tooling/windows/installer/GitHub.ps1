function Save-BoundedHttpResponse {
    param(
        [string]$Url,
        [long]$MaximumBytes,
        [string]$Accept,
        [string]$Destination,
        [string[]]$AllowedRedirectHosts = @()
    )

    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or
        $uri.Host -notin @('api.github.com', 'github.com') -or
        $MaximumBytes -le 0) {
        throw 'The release request URL or response-size limit is invalid.'
    }

    $currentUri = $uri
    $response = $null
    $inputStream = $null
    $outputStream = $null
    $memoryStream = $null
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        for ($redirectCount = 0; $true; $redirectCount++) {
            $request = [System.Net.HttpWebRequest]::Create($currentUri)
            $request.Method = 'GET'
            $request.Accept = $Accept
            $request.UserAgent = 'NumCalsInstaller'
            $request.AllowAutoRedirect = $false
            $request.Timeout = 30000
            $request.ReadWriteTimeout = 30000

            try {
                $response = [System.Net.HttpWebResponse]$request.GetResponse()
            } catch [System.Net.WebException] {
                $errorResponse = $_.Exception.Response
                if ($errorResponse -is [System.Net.HttpWebResponse]) {
                    $statusCode = [int]$errorResponse.StatusCode
                    $errorResponse.Close()
                    throw "The release server returned HTTP $statusCode."
                }
                throw 'The release server could not be reached.'
            }

            if ([int]$response.StatusCode -ge 300 -and
                [int]$response.StatusCode -lt 400) {
                $location = $response.Headers[[System.Net.HttpResponseHeader]::Location]
                if ($redirectCount -ge 5 -or [string]::IsNullOrWhiteSpace($location)) {
                    throw 'The release server returned too many or an invalid redirect.'
                }
                $redirectUri = [Uri]::new($currentUri, $location)
                if ($redirectUri.Scheme -ne 'https' -or
                    $redirectUri.Host -notin $AllowedRedirectHosts) {
                    throw 'The release server redirected to an untrusted HTTPS host.'
                }
                $response.Close()
                $response = $null
                $currentUri = $redirectUri
                continue
            }
            break
        }

        if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
            throw "The release server returned HTTP $([int]$response.StatusCode)."
        }
        if ($response.ContentLength -gt $MaximumBytes) {
            throw "The release response exceeds the $MaximumBytes-byte safety limit."
        }

        if ($Destination) {
            $outputStream = [System.IO.File]::Open(
                $Destination,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
        } else {
            $memoryStream = New-Object System.IO.MemoryStream
            $outputStream = $memoryStream
        }
        $inputStream = $response.GetResponseStream()
        $buffer = New-Object byte[] 65536
        [long]$receivedBytes = 0
        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $receivedBytes += $read
            if ($receivedBytes -gt $MaximumBytes) {
                throw "The release response exceeds the $MaximumBytes-byte safety limit."
            }
            if ($timer.Elapsed -gt [TimeSpan]::FromMinutes(5)) {
                throw 'The release download exceeded the five-minute time limit.'
            }
            $outputStream.Write($buffer, 0, $read)
        }
        if ($response.ContentLength -ge 0 -and $receivedBytes -ne $response.ContentLength) {
            throw 'The release response ended before all declared bytes were received.'
        }

        if ($Destination) {
            return $receivedBytes
        }
        return ,$memoryStream.ToArray()
    } finally {
        if ($inputStream) { $inputStream.Dispose() }
        if ($Destination -and $outputStream) { $outputStream.Dispose() }
        if ($memoryStream) { $memoryStream.Dispose() }
        if ($response) { $response.Close() }
    }
}

function Get-LatestRelease {
    $releaseUrl = "https://api.github.com/repos/$script:RepositoryName/releases/latest"
    $releaseResponse = Save-BoundedHttpResponse -Url $releaseUrl `
        -MaximumBytes (1MB) -Accept 'application/vnd.github+json'
    $release = [System.Text.Encoding]::UTF8.GetString($releaseResponse) |
        ConvertFrom-Json
    if ($release.draft -or $release.prerelease -or
        $release.tag_name -notmatch '^v\d+\.\d+\.\d+$') {
        throw "The latest release for $script:RepositoryName has invalid release metadata."
    }

    $assets = @($release.assets | Where-Object { $_.name -eq 'NumCals-Setup.exe' })
    if ($assets.Count -ne 1) {
        throw "The latest release for $script:RepositoryName must contain exactly one NumCals-Setup.exe."
    }
    $asset = $assets[0]

    if ($null -eq $asset) {
        throw "The latest release for $script:RepositoryName does not contain NumCals-Setup.exe."
    }
    $expectedAssetPath = "/$script:RepositoryName/releases/download/$($release.tag_name)/NumCals-Setup.exe"
    $assetUri = $null
    if (-not [Uri]::TryCreate([string]$asset.browser_download_url, [UriKind]::Absolute, [ref]$assetUri) -or
        $assetUri.Scheme -ne 'https' -or
        $assetUri.Host -ine 'github.com' -or
        $assetUri.AbsolutePath -ine $expectedAssetPath -or
        $asset.size -isnot [long] -and $asset.size -isnot [int] -and
        $asset.size -isnot [double] -or
        [long]$asset.size -le 0 -or
        [long]$asset.size -gt 100MB -or
        [string]$asset.digest -notmatch '^sha256:[a-fA-F0-9]{64}$') {
        throw 'The latest release contains invalid installer metadata.'
    }

    return [pscustomobject]@{
        Release = $release
        Asset = $asset
    }
}
