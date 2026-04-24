# MAIN – Base GUI Application

This folder contains the **main entry point** for the M365 Tool Portal – a standalone
WinForms GUI shell that loads and executes all PowerShell tools in this repository.

## Entry Point

Run `Start-M365ToolPortal.ps1` to open the GUI portal:

```powershell
.\Start-M365ToolPortal.ps1
.\Start-M365ToolPortal.ps1 -TenantId 'contoso.onmicrosoft.com'
```

## Contents

| File | Description |
|------|-------------|
| `Start-M365ToolPortal.ps1` | Standalone GUI portal – WinForms shell that hosts all M365 tools |

## How it works

The portal dot-sources each tool's data script from its own subfolder and renders
the results inside the GUI. The tool scripts remain in their original locations
and are loaded on demand.

## Available Tools

| Tool | Description |
|------|-------------|
| **Get Intune Device Info** | Search Intune managed devices by name, user, or serial number |
| **Bulk Device Delete** | Load a CSV of device names and delete them from Local AD, Entra ID, and/or Intune |

## Prerequisites

- PowerShell 5.1 or later
- `Microsoft.Graph.Authentication` module:
  ```powershell
  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
  ```
