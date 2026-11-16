# Windows release history

## v1.0.2

NumCals v1.0.2 (`1.0.2+3`) was first published on November 15, 2026, then
republished on November 16 with refreshed Windows package assets and release
notes. The release tag points to commit `f92fa6d` on `Windows_Tests`.

### Included

- The first Windows release under the NumCals name, with standard,
  scientific, and currency calculations.
- A PowerShell command with `help`, `update`, `upgrade`, and `remove` actions.
- Setup wizard, portable ZIP, PowerShell release installer, and SHA-256
  manifest assets.
- Installer validation for HTTPS downloads, file size, and SHA-256, with
  install and uninstall safeguards that preserve unrelated files.

### Verification

- [Windows_Tests run 15](https://github.com/Tenqo/NumCals/actions/runs/43959452647)
  passed analysis, tests, packaging, checksum validation, and artifact upload.
- [Release run 4](https://github.com/Tenqo/NumCals/actions/runs/43960686778)
  passed packaging, installer tests, checksum validation, and publication.
- The published asset digests match `SHA256SUMS.txt`.

### Known limitations

- Windows release executables are unsigned; the checksum manifest is published
  through the same GitHub release channel as the assets.
- Setup, update, and uninstall were not manually exercised in a disposable
  Windows virtual machine.
- ARM64 runtime behavior has not been validated; x86 Windows is unsupported.
