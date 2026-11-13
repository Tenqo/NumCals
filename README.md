# FlCalculator

Keyboard-friendly Windows calculator built with Flutter.

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

After a release is published, download `FlCalculator-Setup.exe` from the
project's GitHub Releases page, then double-click it and follow the setup
prompts. It installs for your Windows account and creates a desktop shortcut.
No administrator access or extra software is needed.

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

If `FlCalculator-Setup.exe` is already downloaded, open PowerShell in its
folder and run:

```powershell
Start-Process -FilePath .\FlCalculator-Setup.exe -Wait
```

### Portable version

Download `FlCalculator-portable.zip`, extract it to any folder, and double-click
`flcalculator.exe`. Keep the extracted folder together; no installation is
needed.

## For maintainers

Publishing a GitHub Release automatically builds and attaches the Windows
setup executable, portable ZIP, and PowerShell GitHub installer. End users do
not need to build the app or install development tools.

To run locally, install Flutter stable and the Visual Studio **Desktop
development with C++** workload, then run:

```powershell
flutter pub get
flutter test
flutter run -d windows
```

## Project structure

- `lib/main.dart` — application UI, modes, settings, and calculation history.
- `lib/calculator_engine.dart` — expression parsing and scientific calculations.
- `lib/currency_service.dart` — currency list and reference-rate requests.
- `test/calculator_engine_test.dart` — calculator engine tests.
- `test/calculator_app_widget_test.dart` — app UI and interaction tests.
- `windows/runner/` — native Windows window setup and app icon resources.
- `tooling/windows/` — Windows release build, icon conversion, and update installer.
- `packaging/windows/` — Windows setup installer definition.
- `.github/workflows/release-windows.yml` — builds and uploads release packages.

## License

This project is licensed under the GNU General Public License v3.0 only.
Copyright (C) 2026 Tenqo Digital. See [LICENSE](LICENSE) for details.
