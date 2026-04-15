# Entra ID – Device Info Lookup Tool

A **PowerShell + Windows Forms** GUI tool for quickly looking up computer / device
objects in **Microsoft Entra ID** (formerly Azure Active Directory) and displaying
rich, colour-coded device details in a modern dashboard.

---

## Features (Phase 1)

| Feature | Description |
|---------|-------------|
| 🔍 **Single lookup** | Enter a device display name and see all attributes instantly |
| 📋 **Bulk lookup** | Paste a comma-separated or newline-separated list of names |
| 🏢 **Group lookup** | Enter an Entra ID group name to see all its device members |
| 🌲 **OU lookup** | Enter an on-prem AD OU distinguished name (Hybrid environments, requires RSAT) |
| 🎨 **Colour-coded grid** | Green = compliant, orange = non-compliant, grey = disabled, yellow = stale (90+ days) |
| 📑 **Detail panel** | Click any row for a full attribute view and quick-action buttons |
| 💾 **CSV export** | Save the current result set to a `.csv` file |
| 📊 **Excel export** | Export to formatted `.xlsx` (requires the `ImportExcel` module) |
| 📋 **Copy to clipboard** | Copy the grid as tab-separated text (paste into Excel, Notepad, etc.) |
| 🔎 **Client-side filter** | Filter the already-loaded results without re-querying Graph |
| 🌐 **Open in portal** | Detail panel button opens the selected device in the Entra portal |
| 🌙 **Dark / Light mode** | Toggle between a dark Fluent-inspired theme and a light mode |
| ⌨️ **Keyboard shortcuts** | `F5` = Search, `Ctrl+E` = Export CSV, `Ctrl+F` = Focus filter |

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| PowerShell 5.1+ | Windows PowerShell 5.1 or PowerShell 7+ on Windows |
| Windows OS | WinForms requires Windows |
| Microsoft.Graph module | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| Graph permissions | `Device.Read.All`, `User.Read.All`, `DeviceManagementManagedDevices.Read.All` |
| RSAT (optional) | Required only for the **OU Path** lookup mode in Hybrid environments |
| ImportExcel (optional) | Required only for Excel export: `Install-Module ImportExcel -Scope CurrentUser` |

---

## Quick Start

```powershell
# 1. Install required module (once)
Install-Module Microsoft.Graph -Scope CurrentUser

# 2. Run the tool (sign-in prompt will appear)
.\Get-EntraDeviceInfoTool.ps1

# 3. Or specify a tenant directly
.\Get-EntraDeviceInfoTool.ps1 -TenantId 'contoso.onmicrosoft.com'

# 4. If you already have an authenticated Graph session
.\Get-EntraDeviceInfoTool.ps1 -SkipConnect
```

---

## Usage

### Search modes

| Mode | Input | Example |
|------|-------|---------|
| Computer Name(s) | Single name or comma/newline separated list | `PC-001, PC-002` |
| OU Path (Hybrid) | Full AD distinguished name | `OU=Workstations,DC=contoso,DC=com` |
| Entra Group Name | Exact display name of an Entra ID group | `All-Managed-Devices` |

### Grid colour coding

| Colour | Meaning |
|--------|---------|
| 🟢 Green | Device is compliant |
| 🟠 Orange | Device is non-compliant or MDM not enrolled |
| ⬜ Grey | Device is disabled in Entra |
| 🟡 Yellow | Stale – no sign-in activity in 90+ days |

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `F5` | Run the current search |
| `Enter` | Run search (when input box is focused) |
| `Ctrl+E` | Export results to CSV |
| `Ctrl+F` | Move focus to the filter box |

---

## File Layout

```
Entra-ID/Device-Lookup/
├── Get-EntraDeviceInfoTool.ps1   ← Main entry point – run this
├── Auth.ps1                      ← Authentication (replace with your own)
├── GraphQueries.ps1              ← Microsoft Graph query functions
├── UI/
│   ├── MainForm.ps1              ← WinForms main window
│   ├── DetailPanel.ps1           ← Device detail side panel
│   └── Theme.ps1                 ← Colour palettes and theme helpers
└── Helpers/
    ├── Format-DeviceRow.ps1      ← Graph JSON → display strings
    └── Export-Results.ps1        ← CSV / Excel export and clipboard
```

---

## Authentication

The included `Auth.ps1` uses a simple interactive `Connect-MgGraph` call.
**Replace it** with your organisation's authentication flow if needed:

```powershell
# Service principal with certificate
Connect-MgGraph -ClientId $AppId -TenantId $TenantId -CertificateThumbprint $Thumb

# Managed identity (Azure VM / Automation Account)
Connect-MgGraph -Identity
```

---

## Displayed Device Attributes

| Attribute | Graph Property |
|-----------|---------------|
| Display Name | `displayName` |
| Join Type | `trustType` |
| Registered Owner | `registeredOwners` |
| MDM Enrolled | `isManaged` / Intune record |
| Compliant | `isCompliant` / Intune `complianceState` |
| Operating System | `operatingSystem` + `operatingSystemVersion` |
| Account Enabled | `accountEnabled` |
| Registration Date | `registrationDateTime` |
| Last Activity | `approximateLastSignInDateTime` |
| Device ID | `deviceId` |
| Object ID | `id` |

---

*Tool created from [PLAN.md](./PLAN.md) – Phase 1 implementation.*
