<h1 align="center">SysCalculator</h1>

<p align="center">
  A focused Windows calculator for everyday math, science, and currency conversion.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Built_with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Built with Flutter">
  <img src="https://img.shields.io/badge/Version-1.0-2E8B57?style=for-the-badge" alt="Version 1.0">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=for-the-badge" alt="GNU GPL v3.0"></a>
  <a href="https://github.com/Tenqo/SysCalculator/actions/workflows/release-windows.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/Tenqo/SysCalculator/release-windows.yml?branch=main&amp;style=for-the-badge&amp;label=Windows%20release&amp;logo=githubactions&amp;logoColor=white" alt="Windows release workflow">
  </a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#download">Download</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="#project-tree">Project tree</a> ·
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="windows/runner/resources/app_icon_source.png" width="128" alt="SysCalculator app icon">
</p>

SysCalculator is a Flutter desktop calculator for Windows. It brings standard
arithmetic, scientific tools, and currency conversion together in one compact
app, with keyboard-friendly controls and a choice of light or dark appearance.

## Features

- **Standard and scientific modes:** arithmetic, trigonometry, powers, roots,
  logarithms, factorials, constants, parentheses, and degree/radian options.
- **Currency conversion:** reference rates from
  [Frankfurter](https://frankfurter.dev/). Rates update periodically and are
  not live market quotes. An internet connection is required; no API key is.
- **Quick everyday actions:** copy results, use keyboard or number-pad input,
  and pin the calculator above other windows.
- **Recent calculations:** revisit or reuse the last ten calculations during
  the current session.
- **Comfortable appearance:** follow the Windows theme or choose System, Light,
  or Dark. Light mode uses a warm beige palette.
- **Built-in diagnostics:** check the calculator and currency service when
  something does not work as expected.

## Download

Open the [latest GitHub release](https://github.com/Tenqo/SysCalculator/releases/latest)
and choose the option that suits you:

- **Setup:** download `SysCalculator-Setup.exe` and run it. It installs for your
  Windows account and creates a desktop shortcut; administrator access is not
  required.
- **Portable:** download `SysCalculator-portable.zip`, extract it, and run
  `SysCalculator.exe`. Keep the extracted folder together.
- **PowerShell installer:** download and run the latest setup automatically:

  ```powershell
  $repo = 'Tenqo/SysCalculator'
  $installer = Join-Path $env:TEMP 'Install-LatestRelease.ps1'
  Invoke-WebRequest -Uri "https://github.com/$repo/releases/latest/download/Install-LatestRelease.ps1" -OutFile $installer
  powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Repository $repo
  ```

## Build from source

Install Flutter stable and the Visual Studio **Desktop development with C++**
workload, then run these commands from the project directory:

```powershell
flutter pub get
flutter test
flutter run -d windows
```

Publishing a GitHub Release runs the Windows workflow, which builds and attaches
the setup installer, portable ZIP, and PowerShell installer.

## License

Licensed under the GNU General Public License v3.0 only.
Copyright (C) 2026 Tenqo Digital. See [LICENSE](LICENSE) for details.
