#Requires -Version 5.1
<#
.SYNOPSIS
    Entry point for the Bulk Device Delete Tool.

.DESCRIPTION
    Bootstraps all modules, authenticates to Microsoft Graph, and opens the
    WinForms GUI.

    The tool reads a CSV file containing computer names and can delete each
    device from one or more of the following targets:
      - Local Active Directory (requires RSAT / ActiveDirectory PS module)
      - Microsoft Entra ID (Azure AD)
      - Microsoft Intune (via Microsoft Graph)

    Run this script directly:

        .\Remove-DeviceBulkTool.ps1

    Or with an explicit tenant:

        .\Remove-DeviceBulkTool.ps1 -TenantId 'contoso.onmicrosoft.com'

    The tool requires PowerShell 5.1 or later on Windows (WinForms dependency).

.PARAMETER TenantId
    Optional. Azure AD tenant ID or verified domain name.
    When omitted, Connect-MgGraph will prompt for tenant selection.

.PARAMETER SkipConnect
    Switch. When set, the tool will NOT call Connect-MgGraph and instead assumes
    a Graph session is already established (useful when calling from an existing
    automation script that already authenticated).

.NOTES
    Minimum required Graph scopes:
      - Device.ReadWrite.All                           (Entra ID deletion)
      - DeviceManagementManagedDevices.ReadWrite.All   (Intune deletion)

    File layout expected relative to this script:
      Auth.ps1
      GraphOperations.ps1
      ADOperations.ps1
      UI\Theme.ps1
      UI\MainForm.ps1
      Helpers\Import-DeviceList.ps1
      Helpers\Export-Results.ps1
#>

[CmdletBinding()]
param(
    [string]$TenantId   = $null,
    [switch]$SkipConnect
)

Set-StrictMode -Off   # Relax strictness for WinForms dynamic properties
$ErrorActionPreference = 'Stop'

# ─── Resolve script root ─────────────────────────────────────────────────────
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# ─── Load all modules ─────────────────────────────────────────────────────────
$filesToLoad = @(
    'Auth.ps1'
    'GraphOperations.ps1'
    'ADOperations.ps1'
    'UI\Theme.ps1'
    'Helpers\Import-DeviceList.ps1'
    'Helpers\Export-Results.ps1'
    'UI\MainForm.ps1'
)

foreach ($file in $filesToLoad) {
    $fullPath = Join-Path $ScriptRoot $file
    if (-not (Test-Path $fullPath)) {
        Write-Error "Required file not found: $fullPath"
        exit 1
    }
    . $fullPath
}

# ─── Authenticate ─────────────────────────────────────────────────────────────
if (-not $SkipConnect) {
    try {
        $connectParams = @{}
        if ($TenantId) { $connectParams['TenantId'] = $TenantId }
        Connect-BulkDeleteTool @connectParams
    } catch {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "Authentication failed:`n`n$_`n`nPlease check your credentials and try again.",
            'Authentication Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }
}

# ─── Launch GUI ───────────────────────────────────────────────────────────────
try {
    Show-BulkDeleteForm
} finally {
    if (-not $SkipConnect) {
        Disconnect-BulkDeleteTool
    }
}
