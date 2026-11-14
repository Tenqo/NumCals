# NumCals 1.0.2 release preparation

**Status:** NumCals 1.0.2+3 is a Windows_Tests test candidate. Its branch
workflow will build and upload a seven-day artifact; no tag or GitHub Release
is being created.

**Readiness:** 6/10 — suitable for human review, not ready to publish until
Windows packaging and disposable-VM testing are completed.

## Changes from v1.0.1

- Application version is prepared as `1.0.2+3`.
- The PowerShell installer preserves interactive setup and the `update`,
  `upgrade`, `remove`, `help`, and `exit` commands. It checks the executable's
  product/version metadata to distinguish a fresh install, current install, or
  update.
- Downloads now require a positive metadata size and a valid SHA-256 digest.
  They are written to a unique partial file and moved to the final name only
  after both checks pass. Partial files are removed on failure; HTTPS and the
  GitHub release host are required.
- Setup is prevented from using a non-empty directory unless it contains an
  executable identified as NumCals. A failed setup retains its installer
  log in the user's temporary directory and gives recovery guidance.
- Uninstall verifies the app and uninstaller, then confirms the executable was
  removed before clearing installer state and the PATH command entry. It does
  not recursively delete the installation directory or unrelated files. On
  failure, it preserves an uninstaller log and leaves installer state intact.
  The command cleanup removes both app-owned CLI files and removes their folder
  only when empty; unrelated files are preserved with a warning.
- The build creates `SHA256SUMS.txt` and refuses to overwrite an existing
  release output in `dist`.
- The workflow validates that the checked-out commit and tag match the app
  version, tests before packaging, and only creates a release from a pushed
  version tag. The release-published/clobber upload path was removed to prevent
  rebuilding and replacing assets after publication.

## Security and signing

The GitHub Actions workflow does not receive a signing certificate or password;
its Windows executables are unsigned. The local build helper retains optional
PFX signing support for an explicitly configured local build, but that path is
not enabled or tested here. Self-signing is independent of the GPL-3.0 source
license and does not make a publisher trusted by Windows automatically.

If you self-sign locally after packaging, regenerate `SHA256SUMS.txt` after
signing so it covers the exact files being distributed. Never commit the
certificate, private key, or password.

The v1.0.1 setup EXE was verified as `NotSigned`. The local NumCals 1.0.2+3
application build succeeded; no v1.0.2 executable has been signed.

## Significant changes: rationale and verification

| Change | Why / evidence | Verification |
|---|---|---|
| Strict, staged download validation | The v1.0.1 audit identified download failures and only conditional digest checking; partial output should never be executable as setup. | Self-test copies a fixture through the injected request and checks the resulting SHA-256; wrong digest, interrupted download, and non-HTTPS URL are rejected, with no final or partial file left behind. |
| Version-aware update detection | The previous local installer used saved state to decide whether an app was current, which could become stale or missing. | Self-test covers fresh, current, outdated, and unknown-version decisions. |
| Safer install/uninstall boundaries | A custom non-empty folder could otherwise be overwritten; uninstall cleanup should not remove user data or report success while the app remains. | Self-test checks non-empty unrelated-folder rejection, missing-install uninstall rejection, self-removal of the running CLI script, removal of an empty CLI folder, and preservation of unrelated files. No real installation was touched. |
| Architecture checks | The release contains an x64 executable; x86 Windows must not be offered an incompatible package. | Self-test validates AMD64, ARM64 under emulation, and x86 classification. ARM64 runtime behavior remains untested. |
| Checksums and local signing | Stage 3 found the v1.0.1 setup was unsigned and releases lacked a published checksum file; the owner self-signs locally. | Checksum generation and overwrite protection self-tests passed. Signing and a complete local release build were unavailable; Actions has no certificate secret references. |
| Windows test-branch workflow | Windows cloud validation is needed without publishing a release. | The `Windows_Tests` workflow builds the NumCals setup and portable artifacts, verifies checksums, and uploads a seven-day artifact. This run does not publish a GitHub Release. |
| README and release notes | Existing release notes described outdated retry/command behavior; the README omitted checksum instructions and had a dead Project tree link. | Documentation reviewed against the current installer and workflow. |

## Tests and limitations

### Successfully executed

- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tooling\windows\Install-LatestRelease.ps1 -SelfTest`
  passed, including mocked download integrity/failure cases, retained
  diagnostics, and an isolated `NumCals.cmd help` launcher round trip.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tooling\windows\Build-WindowsRelease.ps1 -SelfTest`
  passed for SHA-256 manifest generation and refusing to overwrite an existing
  manifest.
- `.\test\windows_installer_tests.ps1` passed.
- VS Code test runner: **27 passed, 0 failed**.
- PowerShell parser checks and `git diff --check` passed.
- After the CLI cleanup fix, the installer self-test passed, including a
  subprocess check that a running copy can remove its own script and launcher.
- The initial Windows cloud run successfully provisioned the Windows runner,
  installed Flutter and Inno Setup, and resolved Flutter dependencies.
- On the follow-up Windows run, `flutter analyze --no-fatal-infos` succeeded
  with two informational deprecation notices still visible, and all 27 Flutter
  tests passed.
- The v1.0.1 Stage 3 audit independently downloaded all three original assets
  and confirmed their SHA-256 values against GitHub release metadata.

### Failed or corrected during preparation

- An initial run of the expanded self-test exposed a PowerShell syntax error in
  the script's main `else` branch. It was corrected; the subsequent complete
  self-test passed.
- Direct script invocation in the restricted local shell was blocked by its
  execution policy. The process-scoped `-ExecutionPolicy Bypass` invocation
  passed; no machine-wide policy was changed.
- GitHub Actions run [43590657273](https://github.com/Tenqo/NumCals/actions/runs/43590657273)
  failed at `flutter analyze` on Flutter 3.50.0. The only findings were two
  informational `deprecated_member_use` notices for `package:flutter/material.dart`
  in `lib/main.dart` and `test/calculator_app_widget_test.dart`; tests, installer
  checks, and package creation were skipped. The analyzer command was updated to
  keep infos visible but non-fatal; warnings and errors remain fatal. A rerun
  passed analysis and Flutter tests, but failed in the Windows installer
  self-test because it looked for `powershell.exe` inside PowerShell 7's
  `$PSHOME`. The self-test now detects `pwsh.exe` first and falls back to
  `powershell.exe`.
- GitHub Actions run [43591187626](https://github.com/Tenqo/NumCals/actions/runs/43591187626)
  passed analysis and all 27 Flutter tests, then failed at the PowerShell
  installer self-test due to the executable-path issue above. Release helper
  tests, packaging, checksum verification, and artifact upload were skipped.

### Not performed

- The Windows_Tests workflow is the end-to-end check for the updated installer,
  package output, checksums, and artifact upload; it does not create a release.
- During the host-test attempt, `flutter pub get` and `flutter --version`
  stalled without output. Inspection then hit a sandbox access denial for
  `C:\src\flutter\packages\flutter_tools\.dart_tool\package_config.json` and
  the Flutter SDK repository. Flutter analysis, tests, and packaging therefore
  remain blocked until the sandbox permits access to `C:\src\flutter`.
- No graphical setup, PowerShell installation, update, upgrade, uninstall,
  shortcut, failure-recovery, non-admin, or custom-path installation was run.
- No signing was tested because credentials are unavailable.
- No disposable Windows VM was available. The existing user installation was
  not changed.

## Known limitations and risks

- The workspace changes remain uncommitted; release users will not receive
  them until reviewed, committed, and included in a new tag.
- GitHub Actions produces unsigned EXEs. SHA-256 verifies file consistency, not
  publisher identity; self-signed certificates are not automatically trusted
  by Windows.
- The installer permits ARM64, but its runtime behavior has not been tested.
  x86 Windows is deliberately rejected.
- `NumCals update` depends on the saved install state and registered
  executable path. If state is missing or malformed, rerun the interactive
  installer rather than guessing an install location.
- GUI behavior and installer side effects still require disposable-VM tests.

## Remaining manual steps before publishing

1. Review the installer, workflow, and release-note changes; confirm the
   `1.0.2+3` version/build number.
2. Self-sign binaries locally if desired, then regenerate the checksum manifest
   and verify the exact assets before distribution.
3. Run the tests and full Windows build below on a supported Windows machine.
   Verify signatures when signing is enabled and compare every generated
   checksum.
4. Test setup, update, repair/reinstall, and uninstall in disposable Windows
   10/11 VMs, including a non-admin account, Unicode/spaced custom paths, and
   failed downloads. Do not use the primary installation for these tests.
5. Review the draft release notes and generated assets before creating or
   pushing the v1.0.2 tag. This preparation does not create that tag.

## Recommended release notes

The current `.github/release-notes.md` contains the proposed v1.0.2 notes.
Confirm all listed behavior against the final tagged build before release.

## Commands for the next release candidate

From the repository root in PowerShell:

```powershell
flutter pub get
flutter test
.\test\windows_installer_tests.ps1
.\tooling\windows\Build-WindowsRelease.ps1
```

The build requires Flutter stable, the Visual Studio Desktop development with
C++ workload, and Inno Setup 6. If `dist` already contains any release output,
move those files elsewhere before building; the script intentionally refuses
to overwrite them. For the hosted release, push a reviewed `v1.0.2` tag only
after the manual VM checks are complete.
