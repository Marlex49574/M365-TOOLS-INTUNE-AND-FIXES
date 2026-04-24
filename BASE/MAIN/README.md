# MAIN – Base GUI Application

This folder contains the **main entry point** for the M365 Tools base GUI program.
The base program is a WinForms shell that will launch and host all PowerShell tools
in this repository.

## Entry Point

Run `Get-IntuneDeviceInfoTool.ps1` to open the GUI:

```powershell
.\Get-IntuneDeviceInfoTool.ps1
.\Get-IntuneDeviceInfoTool.ps1 -TenantId 'contoso.onmicrosoft.com'
```

## Contents

| File | Description |
|------|-------------|
| `Get-IntuneDeviceInfoTool.ps1` | Base GUI program – WinForms shell with Tool #1: Get Intune Device Info |

## Prerequisites

- PowerShell 5.1 or later
- `Microsoft.Graph.Authentication` module:
  ```powershell
  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
  ```
