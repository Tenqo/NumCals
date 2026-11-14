<h1 align="center">SysCalculator</h1>

<p align="center">
  A focused Windows calculator for everyday math, science, and currency conversion.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Built_with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Built with Flutter">
  <img src="https://img.shields.io/badge/Version-1.0.2-2E8B57?style=for-the-badge" alt="Version 1.0.2">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=for-the-badge" alt="GNU GPL v3.0"></a>
  <a href="https://github.com/Tenqo/SysCalculator/actions/workflows/release-windows.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/Tenqo/SysCalculator/release-windows.yml?branch=main&amp;style=for-the-badge&amp;label=Windows%20release&amp;logo=githubactions&amp;logoColor=white" alt="Windows release workflow">
  </a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#download">Download</a> ·
  <a href="#updates-and-uninstall">Updates and uninstall</a> ·
  <a href="#verify-a-download">Verify a download</a> ·
  <a href="#build-from-source">Build from source</a> ·
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

- **Setup wizard:** download `SysCalculator-Setup.exe` and run it. This opens
  the graphical installation media, where you can choose the install folder
  and desktop shortcut.
- **Portable:** download `SysCalculator-portable.zip`, extract it, and run
  `SysCalculator.exe`. Keep the extracted folder together.
- **PowerShell-only install:** run the PowerShell installer below. It asks for
  the install folder and shortcut preference, then installs without opening
  the graphical installation media. The command downloads and verifies the
  installer script before running it.

  ```powershell
  $repo = 'Tenqo/SysCalculator'
  $release = "https://github.com/$repo/releases/latest/download"
  $installer = Join-Path $env:TEMP 'Install-LatestRelease.ps1'
  $checksums = Join-Path $env:TEMP 'SHA256SUMS.txt'
  Invoke-WebRequest -UseBasicParsing -Uri "$release/SHA256SUMS.txt" -OutFile $checksums
  Invoke-WebRequest -UseBasicParsing -Uri "$release/Install-LatestRelease.ps1" -OutFile $installer
  $entry = Get-Content $checksums | Where-Object { $_ -match '\s+Install-LatestRelease\.ps1$' }
  if (-not $entry) { throw 'Installer checksum is missing from SHA256SUMS.txt.' }
  $expected = ($entry -split '\s+', 2)[0]
  $actual = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
  if ($actual -ine $expected) { throw 'Installer checksum mismatch; the script was not run.' }
  powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Repository $repo
  ```

The PowerShell installer checks the downloaded setup file's size and SHA-256
before running it. It installs updates automatically when a newer release is
available and adds a `SysCalculator` command to the current user's `PATH`.
Open a new PowerShell window after installation to use the commands below.

## Updates and uninstall

```powershell
SysCalculator update
SysCalculator upgrade
SysCalculator remove
```

`update` installs only when a newer release is available. `upgrade` reinstalls
the latest release, but will not replace an installed version that is newer or
cannot be identified. `remove` asks for confirmation and uses the app's
uninstaller; it does not recursively delete the installation folder or unrelated
user files. The portable version is updated by downloading and extracting the
latest ZIP.

## Verify a download

Download `SHA256SUMS.txt` with the release files, then run this command in the
folder containing the files:

```powershell
Get-Content .\SHA256SUMS.txt | ForEach-Object {
  $expected, $name = $_ -split '\s+', 2
  $actual = (Get-FileHash -LiteralPath $name -Algorithm SHA256).Hash
  if ($actual -ine $expected) { throw "Checksum mismatch: $name" }
  "Verified $name"
}
```

This detects incomplete or changed downloads when the checksum file is
unchanged. It does not independently authenticate the publisher. Release EXEs
published by GitHub Actions are unsigned. GPL-3.0 describes the source license;
it does not authenticate the publisher or make a self-signed certificate
trusted by Windows.

## Build from source

Install Flutter stable and the Visual Studio **Desktop development with C++**
workload, then run these commands from the project directory:

```powershell
flutter pub get
flutter test
flutter run -d windows
```

Run `flutter pub get`, `flutter test`, and
`.\test\windows_installer_tests.ps1` before preparing a build. To build the
Windows packages locally, install Inno Setup 6 and run:

```powershell
.\tooling\windows\Build-WindowsRelease.ps1
```

The script refuses to overwrite existing files in `dist`. The release workflow
validates that the pushed tag matches `pubspec.yaml`, runs installer tests, and
then builds the setup EXE, portable ZIP, PowerShell installer, and checksum
manifest. Pushing a version tag starts the release workflow; do not push a tag
until the release has been reviewed.

## License

Licensed under the GNU General Public License v3.0 only.
Copyright (C) 2026 Tenqo Digital. See [LICENSE](LICENSE) for details.
