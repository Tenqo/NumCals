param(
    [string]$Repository = 'Tenqo/NumCals',
    [string]$Action,
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'
$script:InstallerScriptPath = $PSCommandPath

# BEGIN INSTALLER MODULES
. (Join-Path $PSScriptRoot 'Helpers.ps1')
. (Join-Path $PSScriptRoot 'Validation.ps1')
. (Join-Path $PSScriptRoot 'Config.ps1')
. (Join-Path $PSScriptRoot 'GitHub.ps1')
. (Join-Path $PSScriptRoot 'Download.ps1')
. (Join-Path $PSScriptRoot 'Uninstall.ps1')
. (Join-Path $PSScriptRoot 'Install.ps1')
# END INSTALLER MODULES

if ($LibraryOnly) { return }
Invoke-InstallerWorkflow -Action $Action
