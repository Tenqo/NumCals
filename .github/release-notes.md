SysCalculator is a keyboard-friendly Windows calculator with standard,
scientific, and currency conversion modes.

## Install

- **Setup:** Download `SysCalculator-Setup.exe`, run it, and follow the prompts.
  It installs for your Windows account and does not require administrator
  access.
- **Portable:** Download `SysCalculator-portable.zip`, extract it, and run
  `SysCalculator.exe`. Keep the extracted folder together.

## Install with PowerShell

Open PowerShell and run:

```powershell
$repo = 'Tenqo/SysCalculator'
$installer = Join-Path $env:TEMP 'Install-LatestRelease.ps1'
Invoke-WebRequest -Uri "https://github.com/$repo/releases/latest/download/Install-LatestRelease.ps1" -OutFile $installer
powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Repository $repo
```

For more PowerShell details, return to the [main repository README](https://github.com/Tenqo/SysCalculator#download).
