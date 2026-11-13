param(
    [Parameter(Mandatory = $true)]
    [string]$Repository
)

$ErrorActionPreference = 'Stop'

if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Repository must use the owner/repository format, for example 'Tenqo/SysCalculator'."
}

$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'FlCalculatorInstaller'
}
$releaseUrl = "https://api.github.com/repos/$Repository/releases/latest"
$release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
$asset = $release.assets | Where-Object { $_.name -eq 'FlCalculator-Setup.exe' } |
    Select-Object -First 1

if ($null -eq $asset) {
    throw "The latest release for $Repository does not contain FlCalculator-Setup.exe."
}

$temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) "FlCalculator-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $temporaryPath | Out-Null

try {
    $setupPath = Join-Path $temporaryPath 'FlCalculator-Setup.exe'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $setupPath -Headers $headers
    $process = Start-Process -FilePath $setupPath -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "The FlCalculator setup exited with code $($process.ExitCode)."
    }
}
finally {
    Remove-Item -LiteralPath $temporaryPath -Recurse -Force
}
