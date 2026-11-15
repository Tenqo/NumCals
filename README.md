<a id="top"></a>
<h1 align="center">NumCals</h1>

<p align="center"><b>A keyboard-friendly Windows calculator for everyday math, science, and currency conversion.</b></p>

<p align="center">
  <a href="https://github.com/Tenqo/NumCals/releases/latest"><img src="https://img.shields.io/github/v/release/Tenqo/NumCals?style=flat&amp;label=Stable&amp;color=806BFF&amp;labelColor=252A36" height="24" alt="Latest stable release"></a>
  <a href="https://github.com/Tenqo/NumCals/releases"><img src="https://img.shields.io/github/v/release/Tenqo/NumCals?include_prereleases&amp;style=flat&amp;label=Latest&amp;color=F4B942&amp;labelColor=252A36" height="24" alt="Latest release including betas"></a>
  <a href="https://github.com/Tenqo/NumCals/releases"><img src="https://img.shields.io/github/downloads/Tenqo/NumCals/total?style=flat&amp;label=Downloads&amp;color=35C9A5&amp;labelColor=252A36" height="24" alt="Total downloads"></a>
  <a href="https://github.com/Tenqo/NumCals/stargazers"><img src="https://img.shields.io/github/stars/Tenqo/NumCals?style=flat&amp;label=Stars&amp;color=F4B942&amp;labelColor=252A36&amp;logo=github&amp;logoColor=white" height="24" alt="GitHub stars"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-2D9CDB?style=flat&amp;logo=windows&amp;logoColor=white&amp;labelColor=252A36" height="24" alt="Windows 10 and 11">
  <img src="https://img.shields.io/badge/Built%20with-Flutter-02569B?style=flat&amp;logo=flutter&amp;logoColor=white&amp;labelColor=252A36" height="24" alt="Built with Flutter">
  <a href="#license"><img src="https://img.shields.io/badge/License-AGPL--3.0-35C9A5?style=flat&amp;labelColor=252A36&amp;logo=gnu&amp;logoColor=white" height="24" alt="GNU AGPL-3.0 license"></a>
</p>

<br>

<p align="center">
  <a href="#why-numcals"><img src="https://img.shields.io/badge/Why-252A36?style=for-the-badge" alt="Why NumCals"></a>
  <a href="#download"><img src="https://img.shields.io/badge/Download-252A36?style=for-the-badge" alt="Download"></a>
  <a href="#install"><img src="https://img.shields.io/badge/Install-252A36?style=for-the-badge" alt="Install"></a>
  <a href="#build-from-source"><img src="https://img.shields.io/badge/Build-252A36?style=for-the-badge" alt="Build from source"></a>
  <a href="#features"><img src="https://img.shields.io/badge/Features-252A36?style=for-the-badge" alt="Features"></a>
  <a href="#privacy"><img src="https://img.shields.io/badge/Privacy-252A36?style=for-the-badge" alt="Privacy"></a>
  <a href="#faq"><img src="https://img.shields.io/badge/FAQ-252A36?style=for-the-badge" alt="FAQ"></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-252A36?style=for-the-badge" alt="License"></a>
</p>

<p align="center">
  <b>Just want it?</b> <a href="https://github.com/Tenqo/NumCals/releases/latest">Download the latest stable release</a> and run the setup wizard.
</p>

---

## Why NumCals

The built-in Windows Calculator is fine. NumCals is for when you want more:

- **Keyboard first.** Type your math and hit Enter. No mouse needed.
- **Science tools built in.** Trig, logs, roots, factorials, and more.
- **Currency conversion** without opening a browser tab.
- **History and copy.** Grab your last ten results from the session.

<!-- TODO: add a screenshot or short GIF here, e.g. <p align="center"><img src="docs/screenshot.png" width="600" alt="NumCals screenshot"></p>
     A picture near the top is the single best way to get people to try it. -->

### How to use it

- Type your expression and press **Enter**.
- Use **parentheses** for longer expressions, and switch between **degrees and radians** for trig.
- Copy a result with one action, and revisit your **last ten** calculations in the session history.
- Open the settings for dark/light mode, **always on top**, and the built-in diagnostics.
- See every key in [Keyboard shortcuts](#keyboard-shortcuts).
- Update or remove NumCals from PowerShell with the [`NumCals` commands](#manage-numcals-from-powershell).

---

## Download

> **Works on Windows 10 and 11.**

### Pick a version

| Status | Version | Best for | Download |
| --- | --- | --- | --- |
| <img src="https://img.shields.io/badge/Stable-2EA043?style=flat" alt="Stable"> | **Latest stable** | Most people. The safe pick. | [Get latest stable](https://github.com/Tenqo/NumCals/releases/latest) |
| <img src="https://img.shields.io/badge/Beta-F4B942?style=flat" alt="Beta"> | **Latest beta** | Trying newer stuff | [Get latest beta](https://github.com/Tenqo/NumCals/releases) |

### Pick a file

Every release has two files. Grab one:

<img src="https://img.shields.io/badge/Recommended-806BFF?style=flat" alt="Recommended"> **[Setup wizard](#install-with-the-setup-wizard):** Run `NumCals-Setup.exe` and follow the prompts.
Best if you want it installed like a normal app.

<img src="https://img.shields.io/badge/Portable-2D9CDB?style=flat" alt="Portable"> **[Portable ZIP](#install-with-the-portable-zip):** Extract it and run the app. Nothing gets installed.
Keep all the files together in the same folder.

<img src="https://img.shields.io/badge/Command%20line-252A36?style=flat&amp;logo=powershell&amp;logoColor=white" alt="Command line"> Prefer using a terminal? Use **[PowerShell](#install-with-powershell)**, then follow the steps there.

> **Note:** The v1.0.1 file names still use the old product name from before the rename. That's normal.

> **Seeing a blue "Windows protected your PC" screen?** That's expected, since NumCals isn't code signed yet. See the [FAQ](#faq) for how to get past it safely.

---

## Install

Pick a method below, or build it yourself.

### Install with the setup wizard

1. Go to the [latest release](https://github.com/Tenqo/NumCals/releases/latest) (or the [releases page](https://github.com/Tenqo/NumCals/releases) if you want a beta).
2. Under **Assets**, download the setup `.exe`.
3. Double-click it and follow the prompts.
4. Pick your install folder and whether you want a shortcut.
5. Open NumCals from the Start menu or your shortcut.

> **Note:** Releases up to v1.0.1 use the old product name in the file names. The new `NumCals-Setup.exe` only shows up once the next release is published.

### Install with the portable ZIP

1. Download the portable `.zip` and `SHA256SUMS.txt` from the [latest release](https://github.com/Tenqo/NumCals/releases/latest).
2. Open PowerShell in the folder containing both downloads.
3. Check the ZIP's hash:

   ```powershell
   Get-FileHash .\NumCals-portable.zip -Algorithm SHA256
   ```

4. Compare the displayed hash with the `NumCals-portable.zip` entry in `SHA256SUMS.txt`. If they differ, do not extract or run it.
5. Right-click the verified ZIP, choose **Extract All**, then run `NumCals.exe`. Keep all files together.

> This check is only for the portable ZIP. The PowerShell installer verifies its setup `.exe` automatically. The ZIP and checksum share the GitHub release channel, so this detects corruption, not a compromised publisher. Older releases without `SHA256SUMS.txt` cannot be verified this way. Keep Windows' downloaded-file warning intact.

### Install with PowerShell

**What it does:** Downloads the PowerShell installer and its checksum manifest, verifies the
script, then runs it. The script then downloads and verifies the setup `.exe` before running it,
so no separate setup checksum command is needed. It uses PowerShell prompts; it does **not** open
the graphical setup wizard.

> **Heads up:** The script link uses GitHub's `/releases/latest`, which skips anything marked as a
> pre-release. Until the new release is published, it still points at the existing release,
> not the upcoming NumCals installer. GitHub goes by each release's prerelease setting, not its
> title, so this might not match the Stable/Beta labels above. If you want a specific version,
> download the `.exe` you want from the [releases page](https://github.com/Tenqo/NumCals/releases)
> and install it with the [setup wizard](#install-with-the-setup-wizard).

Copy this single line into PowerShell. It verifies the downloaded script, then the installer
verifies the setup `.exe` before running it:

```powershell
$r='https://github.com/Tenqo/NumCals/releases/latest/download';$p="$env:TEMP\NumCals-Install.ps1";$c="$env:TEMP\NumCals-SHA256SUMS.txt";iwr "$r/Install-LatestRelease.ps1" -OutFile $p;iwr "$r/SHA256SUMS.txt" -OutFile $c;$h=@(gc $c|?{$_ -match '\s+Install-LatestRelease\.ps1$'});if($h.Count -ne 1 -or (Get-FileHash $p -Algorithm SHA256).Hash -ine (($h[0] -split '\s+')[0])){throw 'Installer checksum mismatch. Do not run.'};& $p -Repository 'Tenqo/NumCals'
```

> **Trust limitation:** GitHub's asset digest and `SHA256SUMS.txt` are published through the same
> repository/release channel. They help detect corruption, but are not an independent publisher
> signature and cannot protect against a compromised release account. NumCals does not currently
> publish an independent signature or attestation. You are trusting the NumCals GitHub publisher
> and the HTTPS connection.

<details>
<summary>Optional: verify a setup file downloaded manually</summary>

Compare the downloaded setup file with the published checksum:

```powershell
Get-FileHash .\NumCals-Setup.exe -Algorithm SHA256
Select-String -Path .\SHA256SUMS.txt -Pattern 'NumCals-Setup.exe'
```

The two hashes should match exactly. If they don't, don't run the file.

</details>

> **Note:** The public v1.0.0 and v1.0.1 releases don't have checksums. The current test
> build does.

<details>
<summary><b>For testers: v1.0.2 Beta (unreleased)</b></summary>

<br>

[Open the Windows test run](https://github.com/Tenqo/NumCals/actions/runs/43652142483)
to grab the setup and portable files. You need a GitHub login, and the files
expire after seven days.

</details>

### Update or uninstall NumCals

After installing a newer release, open a new PowerShell window. The v1.0.1 release did not register a PowerShell command.

Copy and run the command you need:

- Help: `NumCals help`
- Update only if a newer release is available: `NumCals update`
- Reinstall the latest release: `NumCals upgrade`
- Uninstall after confirmation: `NumCals remove`

You can also uninstall an installed copy from **Settings → Apps → Installed apps**; v1.0.1 may appear as SysCalculator. For the portable ZIP, close the app and delete its folder. To update a portable copy, extract the new ZIP to a fresh folder and delete the old one.

### Build from source

#### What you need

| Tool | Details |
| --- | --- |
| OS | Windows 10 or 11 (64-bit) |
| Git | [Git for Windows](https://git-scm.com/download/win) |
| Flutter | SDK `3.50.0` (stable) |
| Visual Studio | **Desktop development with C++** workload, MSVC x64/x86 build tools, a Windows SDK, and CMake tools |
| Inno Setup 6 | Optional. Only for building setup and release packages |

> **Tip:** Not sure Visual Studio is set up right? Follow the
> [Flutter Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup),
> then run `flutter doctor -v` to check.

#### Run, test, and build

```powershell
git clone https://github.com/Tenqo/NumCals.git
cd NumCals
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

The executable ends up at `build\windows\x64\runner\Release\NumCals.exe`.

#### Build the installer and portable ZIP

Install Inno Setup 6, then run the packaging helper. It makes the setup wizard,
portable ZIP, installer script, and checksums:

```powershell
.\tooling\windows\Build-WindowsRelease.ps1
```

##### Build only the standalone PowerShell installer

The installer source is split into modules under `tooling\windows\installer`, but
the generated release script is standalone. To bundle only that `.ps1`—without
building the Flutter app, setup wizard, or portable ZIP—choose a new empty output
directory and run:

```powershell
.\tooling\windows\Build-WindowsRelease.ps1 -InstallerScriptOnly -OutputDirectory build\installer-script-only
```

The output is `Install-LatestRelease.ps1` in that directory. The builder refuses
to overwrite an existing installer there.

#### Contributing

Pull requests are welcome. Before you open one, run `flutter analyze` and `flutter test` and make sure both pass. For bigger changes, [open an issue](https://github.com/Tenqo/NumCals/issues) first so we can talk it through.

### Release history

| Status | Version | Notes |
| --- | --- | --- |
| <img src="https://img.shields.io/badge/Unreleased-E0565B?style=flat" alt="Unreleased"> | [v1.0.2 Beta](https://github.com/Tenqo/NumCals/actions/runs/43652142483) | Windows_Tests build, workflow passed. AGPL-3.0 |
| <img src="https://img.shields.io/badge/Beta-F4B942?style=flat" alt="Beta"> | [v1.0.1 Beta](https://github.com/Tenqo/NumCals/releases/tag/v1.0.1) | Published before the rename. GPL-3.0 |
| <img src="https://img.shields.io/badge/Stable-2EA043?style=flat" alt="Stable"> | [v1.0.0 Stable](https://github.com/Tenqo/NumCals/releases/tag/v1.0.0) | GPL-3.0 |

---

## Features

### Calculate

Standard and scientific math in one place:

- Trigonometry, powers, roots, and logarithms
- Factorials and constants
- Parentheses for longer expressions
- Degree and radian modes

### Convert currency

- Uses [Frankfurter](https://frankfurter.dev/) reference rates
- Rates update periodically and are **not** live market quotes
- Needs an internet connection
- No API key needed

### Work faster

- Type with the keyboard or number pad
- Copy results with one action
- Revisit your last ten calculations from the current session
- Update, reinstall, or remove NumCals from PowerShell with `NumCals update`, `NumCals upgrade`, and `NumCals remove`

### Make it your own

- Pick dark or light mode, or let it match your system appearance
- Keep the calculator on top of other windows
- Check calculator and currency-service status with built-in diagnostics

### Keyboard shortcuts

Use these while the calculator window is focused.

| | Keys | What it does |
| :--- | :---: | :--- |
| **Numbers** | <kbd>0</kbd> – <kbd>9</kbd> | Enter numbers. The number pad works too. |
| | <kbd>.</kbd> or <kbd>,</kbd> | Enter a decimal point. |
| **Operators** | <kbd>+</kbd> <kbd>-</kbd> <kbd>*</kbd> <kbd>/</kbd> | Add, subtract, multiply, and divide. |
| | <kbd>(</kbd> <kbd>)</kbd> <kbd>%</kbd> <kbd>^</kbd> <kbd>!</kbd> | Parentheses, percent, powers, and factorials. |
| **Calculate** | <kbd>Enter</kbd> or <kbd>=</kbd> | Show the result. Numpad <kbd>Enter</kbd> and numpad <kbd>=</kbd> work too. |
| **Edit** | <kbd>Backspace</kbd> | Delete the last key. |
| | <kbd>Esc</kbd> or <kbd>Delete</kbd> | Clear the calculation. |

A shorter version of this list is also in the app under **Settings → Keyboard shortcuts**.

---

## Privacy

- No accounts, no analytics, no tracking.
- The only network requests are to Frankfurter, for currency lists and exchange rates.
- Clicking the Frankfurter service link opens its website in your default browser.

---

## Credits

- Currency data comes from [Frankfurter](https://frankfurter.dev/).
- Built with [Flutter](https://flutter.dev/).

Like NumCals? A ⭐ on the [repo](https://github.com/Tenqo/NumCals) helps other people find it.

---

## Troubleshooting

<details>
<summary><b>Currency conversion isn't loading</b></summary>

<br>

Currency lists and rates come from Frankfurter, so you need an internet connection. Open the built-in diagnostics to check the currency-service status. Everything else works offline.

</details>

<details>
<summary><b>The portable version won't start</b></summary>

<br>

Make sure you extracted the whole ZIP (right-click → **Extract All**) and that all the files are still in the same folder as `NumCals.exe`.

</details>

<details>
<summary><b>The NumCals command isn't found in PowerShell</b></summary>

<br>

Close PowerShell and open a new window, since the newer installer adds the command for your Windows user. Run `NumCals help` to see the available commands. The command is added by the installer, so it won't exist if you only extracted the portable ZIP. The v1.0.1 release did not register a PowerShell command; uninstall that version from **Settings → Apps → Installed apps** (it may be listed as SysCalculator).

</details>

<details>
<summary><b>Something looks wrong after an update</b></summary>

<br>

Run `NumCals upgrade` to reinstall the latest release. It keeps your install location and shortcut choice. If you build from source, run `flutter doctor -v` instead. If it still happens, [open an issue](https://github.com/Tenqo/NumCals/issues) with your Windows and NumCals versions.

</details>

---

## FAQ

<details>
<summary><b>Does it work on Mac or Linux?</b></summary>

<br>

Not right now. Windows 10 and 11 only.

</details>

<details>
<summary><b>Does it need internet?</b></summary>

<br>

Only for currency conversion. Everything else works offline.

</details>

<details>
<summary><b>Are the exchange rates live?</b></summary>

<br>

No. They're reference rates from Frankfurter and update periodically, so don't use them for trading.

</details>

<details>
<summary><b>Does it save my history?</b></summary>

<br>

Only for the current session. Close the app and it's gone.

</details>

<details>
<summary><b>Windows shows a warning when I run the installer.</b></summary>

<br>

Windows SmartScreen pops up a blue "Windows protected your PC" screen when it doesn't
recognize an app yet. NumCals isn't code signed, so you'll probably see it. That's normal.

To get past it:

1. Click **More info**.
2. Click **Run anyway**.

> **Warning:** Only do this if you downloaded the file from the
> [official releases page](https://github.com/Tenqo/NumCals/releases). If you got it
> anywhere else, don't run it.

</details>

<details>
<summary><b>Found a bug or want a feature?</b></summary>

<br>

[Open an issue](https://github.com/Tenqo/NumCals/issues). For bugs, include your
Windows version and the NumCals version you're on. Steps to reproduce it help a lot.

> **Security problem?** Don't post it in a public issue. Report it privately
> instead (see the next question).

</details>

<details>
<summary><b>Found a security problem? How do I report it?</b></summary>

<br>

Please report it privately so nobody can abuse it before it's fixed. Don't open a
public issue, post it on social media, or share details anywhere public.

**What counts as a security problem:**

- The installer or PowerShell script doing something it shouldn't
- Release files that look swapped, edited, or don't match their checksum
- Someone being able to mess with the currency lookup or the data the app gets back
- Anything that lets the app run code or touch files it shouldn't

> **Tip:** Not sure if it counts? Report it privately anyway. Better safe than sorry.

**How to report it:**

1. Go to the [Security tab](https://github.com/Tenqo/NumCals/security) on the repo.
2. Click **Report a vulnerability**.
3. Tell us what you found and how to reproduce it.

**What to include:**

- The NumCals version and your Windows version
- Step-by-step instructions to make it happen
- What you expected vs. what actually happened
- Screenshots or a short video if that helps

> **Please don't** include real personal info or passwords in your report. You'll get a
> reply once it's been looked at.

</details>

---

## License

The unreleased **v1.0.2 Beta** uses the
[GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE).

Published releases up to and including **v1.0.1** stay under the
[GNU General Public License v3.0 (GPL-3.0)](https://github.com/Tenqo/NumCals/blob/v1.0.1/LICENSE).

<br>

<p align="center">
  <img src="https://img.shields.io/badge/Made%20by-Tenqo%20Digital%20Group-806BFF?style=flat&amp;labelColor=252A36" height="20" alt="Made by Tenqo Digital Group">
  <a href="https://github.com/Pirootz"><img src="https://img.shields.io/badge/Dev-Pirootz-2D9CDB?style=flat&amp;labelColor=252A36" height="20" alt="Dev: Pirootz"></a>
  <a href="https://github.com/Tenqo"><img src="https://img.shields.io/badge/Dev-Tenqo-35C9A5?style=flat&amp;labelColor=252A36" height="20" alt="Dev: Tenqo"></a>
</p>

<p align="right"><a href="#top">↑ Back to top</a></p>
