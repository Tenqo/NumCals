## What's new

- Refreshed the Windows distribution for NumCals v1.0.2.
- This replaces the earlier v1.0.2 package assets; the application version and
  features are unchanged from the original release.
- NumCals provides standard, scientific, and currency calculations, plus the
  PowerShell `help`, `update`, `upgrade`, and `remove` commands.

## Where to find it

The release assets are listed below: `NumCals-Setup.exe`,
`NumCals-portable.zip`, `Install-LatestRelease.ps1`, and `SHA256SUMS.txt`.

## How it works

`NumCals update` compares the installed version with the latest release and
downloads only when a newer version is available. `upgrade` reinstalls the
current release, while `remove` asks for confirmation before uninstalling.
The PowerShell release script validates the download over HTTPS using its
published size and SHA-256 digest before launching the setup executable.
