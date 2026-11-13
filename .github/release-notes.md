SysCalculator is a keyboard-friendly Windows calculator with standard,
scientific, and currency conversion modes.

## Install

- **Setup wizard:** Download `SysCalculator-Setup.exe` and run it. The
  graphical installation media lets you choose the folder and shortcut.
- **Portable:** Download `SysCalculator-portable.zip`, extract it, and run
  `SysCalculator.exe`. Keep the extracted folder together.

## PowerShell-only installation

Use the separate PowerShell installer to install entirely from the console.
It asks for the install folder and shortcut preference and does not open the
graphical installation media.

```powershell
$repo = 'Tenqo/SysCalculator'
$installer = Join-Path $env:TEMP 'Install-LatestRelease.ps1'
Invoke-WebRequest -Uri "https://github.com/$repo/releases/latest/download/Install-LatestRelease.ps1" -OutFile $installer
powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Repository $repo
```

The installer verifies the download, supports retrying a failed install, and
stays open for update, upgrade, and reinstall commands. For more details,
return to the [main repository README](https://github.com/Tenqo/SysCalculator#download).
