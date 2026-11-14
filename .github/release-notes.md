## SysCalculator 1.0.2

### Improvements

- The PowerShell installer detects the installed app version and applies an
  update only when a newer release is available. `upgrade` reinstalls the
  latest version without downgrading an unrecognized or newer installation;
  `remove` uninstalls after confirmation.
- Downloads are staged in a temporary file and checked against the exact
  release size and SHA-256 digest before setup runs.
- The installer refuses to use a non-empty folder that is not already a
  SysCalculator installation, and it preserves diagnostic logs when setup or
  uninstallation fails.
- Releases include `SHA256SUMS.txt` for checking downloaded assets.

### Security

- GitHub Actions publishes unsigned Windows executables. Verify the release
  checksums before use; a self-signed certificate is not trusted by Windows
  automatically.
