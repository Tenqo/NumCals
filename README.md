# SysCalculator

Version 1.0 | Keyboard-friendly Windows calculator built with Flutter.

## Features

- **Standard and scientific calculations:** arithmetic, trigonometry, powers,
  roots, logarithms, factorials, constants, parentheses, and degree/radian
  modes.
- **Currency conversion:** converts using public Frankfurter reference rates.
  Rates update periodically; they are not live market quotes.
- **Everyday conveniences:** copy results, recall the last ten calculations,
  use keyboard or number-pad input, and keep the window on top.
- **Appearance and diagnostics:** follow the Windows theme or choose System,
  Light, or Dark in Settings. Light mode uses warm beige colors; diagnostics
  check the calculator and currency service.

The converter requires an internet connection, but no API key. Frankfurter
provides rates for 219 currencies and 39 other assets. See
[Frankfurter](https://frankfurter.dev/) for source details.

## Install on Windows

### 1. Normal install (recommended)

After a release is published, open the [latest release page on
GitHub](https://github.com/Tenqo/SysCalculator/releases/latest). Download
`SysCalculator-Setup.exe`, then double-click it and follow the setup prompts.
It installs for your Windows account and creates a desktop shortcut. No
administrator access or extra software is needed.

### 2. Install the latest version from GitHub with PowerShell

After a release is published, open PowerShell and run these commands,
using the project repository:

```powershell
$repo = 'Tenqo/SysCalculator'
$installer = Join-Path $env:TEMP 'Install-LatestRelease.ps1'
Invoke-WebRequest -Uri "https://github.com/$repo/releases/latest/download/Install-LatestRelease.ps1" -OutFile $installer
powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Repository $repo
```

This downloads and runs the latest setup executable. It uses PowerShell
included with Windows; no Flutter, Visual Studio, or administrator access is
needed.

### 3. Run the downloaded setup with PowerShell

If `SysCalculator-Setup.exe` is already downloaded, open PowerShell in its
folder and run:

```powershell
Start-Process -FilePath .\SysCalculator-Setup.exe -Wait
```

### Portable version

Download `SysCalculator-portable.zip`, extract it to any folder, and double-click
`SysCalculator.exe`. Keep the extracted folder together; no installation is
needed.

## Quality-of-life features

Small details make everyday calculations more convenient:

- **Keyboard-friendly input:** enter calculations with the keyboard or number
  pad, and use shortcuts for common actions.
- **Recent calculations:** revisit or reuse the last ten calculations during
  the current session.
- **Quick result copying:** copy the displayed answer without selecting it.
- **Stay on top:** keep the calculator visible while working in another app.
- **Comfortable appearance:** follow the Windows theme or choose System, Light,
  or Dark mode. Light mode uses a warm beige palette.
- **Built-in diagnostics:** check the calculator and currency service when
  something does not work as expected.

## License

This project is licensed under the GNU General Public License v3.0 only.
Copyright (C) 2026 Tenqo Digital. See [LICENSE](LICENSE) for details.
