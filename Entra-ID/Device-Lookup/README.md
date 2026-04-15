# Entra ID – Device Info Lookup Tool

A **PowerShell + Windows Forms** GUI tool for quickly looking up computer / device
objects in **Microsoft Entra ID** (formerly Azure Active Directory) and displaying
rich, colour-coded device details in a modern dashboard.

---

## Table of Contents

1. [How the Program Works](#how-the-program-works)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Installation – Step by Step](#installation--step-by-step)
5. [Running the Tool](#running-the-tool)
6. [GUI Walkthrough](#gui-walkthrough)
7. [Search Modes](#search-modes)
8. [Reading the Results Grid](#reading-the-results-grid)
9. [Device Detail Panel](#device-detail-panel)
10. [Exporting Results](#exporting-results)
11. [Keyboard Shortcuts](#keyboard-shortcuts)
12. [Authentication](#authentication)
13. [File Layout](#file-layout)
14. [Displayed Device Attributes](#displayed-device-attributes)
15. [Troubleshooting](#troubleshooting)

---

## How the Program Works

```
You run Get-EntraDeviceInfoTool.ps1
          │
          ▼
  Auth.ps1 – signs you in to Microsoft Graph
  (a browser sign-in window will appear)
          │
          ▼
  The GUI window opens (WinForms dashboard)
          │
          ▼
  You type a device name and press Search
          │
          ▼
  GraphQueries.ps1 – queries the Microsoft Graph API
  for matching Entra ID device objects
          │
          ▼
  Results are colour-coded and shown in the grid
  Click any row → Detail Panel shows full attributes
          │
          ▼
  Export to CSV / Excel / Clipboard when done
          │
          ▼
  Close the window → disconnects from Microsoft Graph
```

The tool is entirely **read-only** – it only queries device information and
never modifies any data in your tenant.  No data is sent anywhere other than
to the Microsoft Graph API (the same API used by the Entra portal itself).

---

## Features

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
| **Windows 10 / 11** | The GUI (WinForms) only runs on Windows |
| **PowerShell 5.1 or later** | Included with Windows 10/11 by default |
| **Microsoft.Graph module** | Free PowerShell module from the PowerShell Gallery |
| **Entra ID permissions** | Your account needs at least `Device.Read.All` and `User.Read.All` |
| **Internet access** | Required to reach the Microsoft Graph API |
| RSAT *(optional)* | Required only for the **OU Path** search mode in Hybrid AD environments |
| ImportExcel *(optional)* | Required only for Excel (`.xlsx`) export |

> **Do I need an admin account?**  
> You need an account that has been granted the Graph permissions listed above.
> A standard user account works **if** those delegated permissions have been
> consented for your tenant by a Global Admin.  A **Global Administrator** or
> **Cloud Device Administrator** role always has sufficient permissions.

---

## Installation – Step by Step

### Step 1 – Download the tool files

Download or clone this repository so that the following folder structure is
present on your PC:

```
Entra-ID\Device-Lookup\
├── Get-EntraDeviceInfoTool.ps1
├── Auth.ps1
├── GraphQueries.ps1
├── UI\
│   ├── MainForm.ps1
│   ├── DetailPanel.ps1
│   └── Theme.ps1
└── Helpers\
    ├── Format-DeviceRow.ps1
    └── Export-Results.ps1
```

> **Tip:** Keep all files together.  The tool uses relative paths to load its
> modules – moving individual files will break it.

### Step 2 – Allow PowerShell to run scripts (one-time)

By default Windows blocks unsigned scripts.  Open **PowerShell as
Administrator** and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

When prompted, type `Y` and press **Enter**.

> `RemoteSigned` means locally-saved scripts can run without a signature.
> You only need to do this once per user account.

### Step 3 – Install the Microsoft.Graph module (one-time)

Open **PowerShell** (no administrator rights needed) and run:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Type `Y` and press **Enter** when asked to trust the PowerShell Gallery.

The download is ~200 MB and may take a few minutes.

> **Already installed?** Update to the latest version with:
> ```powershell
> Update-Module Microsoft.Graph
> ```

### Step 4 – (Optional) Install ImportExcel for Excel export

Only needed if you want to export results as `.xlsx`:

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

---

## Running the Tool

### Option A – Double-click shortcut (easiest)

1. Navigate to the `Entra-ID\Device-Lookup\` folder in File Explorer.
2. Hold **Shift** and **right-click** `Get-EntraDeviceInfoTool.ps1`.
3. Select **"Run with PowerShell"**.

### Option B – From a PowerShell prompt (recommended)

```powershell
# Navigate to the folder
cd "C:\Path\To\Entra-ID\Device-Lookup"

# Run the tool (sign-in prompt will appear)
.\Get-EntraDeviceInfoTool.ps1

# Run against a specific tenant
.\Get-EntraDeviceInfoTool.ps1 -TenantId 'contoso.onmicrosoft.com'

# Skip sign-in if you already authenticated in the same PowerShell session
.\Get-EntraDeviceInfoTool.ps1 -SkipConnect
```

### What happens when you run it

1. A **progress message** appears in the console: `Connecting to Microsoft Graph…`
2. Your **default browser opens** with a Microsoft sign-in page.
3. Sign in with your work / school account.
4. The browser shows **"Authentication complete"** and you can close it.
5. The **GUI window opens** automatically.

---

## GUI Walkthrough

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  🔵  Entra ID – Device Info Lookup                          [─] [□] [✕]    │
├───────────────────────────────────────────────────────── ① Title bar ───────┤
│                                                                              │
│  ② Search mode:  ● Computer Name(s)   ○ OU Path (Hybrid AD)                │
│                  ○ Entra Group Name                                          │
│                                                                              │
│  ③ Input: [  PC-001, PC-002                               ] [🔍 Search]     │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ④ Results grid                                         │ ⑦ Detail panel   │
│  ┌──────────────────────────────────────────────────┐  │ ┌───────────────┐ │
│  │ Name    │Join Type│ Owner    │MDM│Compliant│ OS  │  │ │ Device Details│ │
│  │─────────┼─────────┼──────────┼───┼─────────┼─────│  │ │───────────────│ │
│  │ PC-001  │AAD Join │john@…   │✅ │✅ Yes   │Win11│  │ │ Display Name  │ │
│  │ PC-002  │Hybrid   │—        │❌ │❌ No    │Win10│  │ │ Join Type     │ │
│  │ PC-003  │AAD Join │sara@…   │✅ │⚠️ Stale │Win11│  │ │ Owner         │ │
│  └──────────────────────────────────────────────────┘  │ │ …             │ │
│                                                         │ │               │ │
│                                                         │ │[🌐 Entra Portal]│
│                                                         │ │[📋 Copy ID]   │ │
│                                                         │ └───────────────┘ │
├──────────────────────────────────────────────────────────────────────────────┤
│  ⑤ [💾 CSV]  [📊 Excel]  [📋 Copy]  [🗑 Clear]   Filter: [____________]   │
├──────────────────────────────────────────────────────────────────────────────┤
│  ⑥ Ready                                          ████░░░░  3 devices      │
└─────────────────────────────────────────────────────────────────────────────┘
```

| # | Area | What it does |
|---|------|--------------|
| ① | **Title bar** | Shows the app name; minimise / maximise / close as normal |
| ② | **Search mode** | Select how you want to search (see [Search Modes](#search-modes)) |
| ③ | **Input + Search button** | Type your query here and press **Search** or `F5` |
| ④ | **Results grid** | Sortable, colour-coded table of found devices; click a column header to sort |
| ⑤ | **Action toolbar** | Export or clear results; type in the Filter box to narrow down rows |
| ⑥ | **Status bar** | Shows current status, a progress bar during queries, and result count |
| ⑦ | **Detail panel** | Appears when you click a row; shows every attribute and action buttons |

---

## Search Modes

Select the radio button that matches what you want to look up:

### 🖥 Computer Name(s)  *(default)*

Enter one or more device **display names** exactly as they appear in Entra ID.

| What to type | Example |
|---|---|
| Single device | `DESKTOP-ABC123` |
| Multiple devices (comma-separated) | `PC-001, PC-002, PC-003` |
| Multiple devices (one per line) | Type each name on its own line |

> Names are matched by **exact display name** (case-insensitive).  
> Partial / wildcard search is not supported in this mode.

### 🌲 OU Path (Hybrid AD)

For **Hybrid Azure AD** environments where devices are also joined to
on-premises Active Directory.  Enter the full **Distinguished Name** of the OU:

```
OU=Workstations,DC=contoso,DC=com
```

This mode queries on-premises AD (via RSAT `Get-ADComputer`) for all computers
in that OU, then enriches each result with data from Microsoft Graph.

> **Requires:** RSAT Active Directory tools installed on the machine running
> the script, and connectivity to a domain controller.

### 🏢 Entra Group Name

Enter the **exact display name** of an Entra ID (Azure AD) group.  The tool
retrieves all **device members** of that group.

```
All-Managed-Laptops
```

> The group must exist in Entra ID and contain device objects.
> User-only groups will return zero results.

---

## Reading the Results Grid

Each row represents one device found in Entra ID.  **Click a column header**
to sort by that column.  Rows are **colour-coded** at a glance:

| Row colour | Meaning |
|------------|---------|
| 🟢 **Green** | Device is MDM-enrolled **and** compliant |
| 🟠 **Orange** | Device is non-compliant or not MDM-enrolled |
| ⬜ **Grey / Muted** | Device account is **disabled** in Entra ID |
| 🟡 **Yellow** | Device is **stale** – no sign-in activity in 90 or more days |

### Grid columns

| Column | What it shows |
|--------|---------------|
| **Name** | Device display name in Entra ID |
| **Join Type** | How the device joined Entra (AAD Joined, Hybrid, Registered) |
| **Owner** | Display name of the registered owner (user) |
| **MDM** | Whether the device is enrolled in Intune / MDM (✅ / ❌) |
| **Compliant** | Intune compliance state (✅ Yes / ❌ No / —) |
| **OS** | Operating system and version |
| **Enabled** | Whether the device account is enabled in Entra (✅ / ❌) |
| **Reg. Date** | Date the device was registered / joined |
| **Last Active** | Approximate date of the last sign-in activity |

### Client-side filter

Type anything in the **Filter** box (bottom toolbar) to instantly narrow the
displayed rows to only those containing that text in any visible column.  This
does **not** re-query Microsoft Graph – it filters the results already loaded.

Press `Ctrl+F` to jump straight to the filter box from anywhere in the window.

---

## Device Detail Panel

**Click any row** in the results grid to open the detail panel on the right.
It shows every attribute for that device in a scrollable key → value list,
plus two action buttons at the bottom:

| Button | Action |
|--------|--------|
| 🌐 **Open in Entra Portal** | Opens the device's page in `entra.microsoft.com` in your browser |
| 📋 **Copy Device ID** | Copies the Entra Device ID (GUID) to your clipboard |

To **close** the detail panel, click somewhere else in the grid or press `Escape`.

---

## Exporting Results

Use the buttons in the **action toolbar** at the bottom of the window:

| Button | Keyboard | What it creates |
|--------|----------|-----------------|
| 💾 **Export CSV** | `Ctrl+E` | Saves a `.csv` file – opens a Save dialog |
| 📊 **Export Excel** | — | Saves a formatted `.xlsx` file (requires `ImportExcel` module) |
| 📋 **Copy Table** | — | Copies the grid as tab-separated text – paste into Excel or Notepad |
| 🗑 **Clear** | — | Clears the grid and resets the status bar |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `F5` | Run the current search |
| `Enter` | Run search (when the input box has focus) |
| `Ctrl+E` | Export results to CSV |
| `Ctrl+F` | Move focus to the filter box |

---

## Authentication

### How sign-in works

When you run the tool, `Auth.ps1` calls `Connect-MgGraph` which opens a
**Microsoft browser sign-in page**.  Sign in with your work or school account.
After successful sign-in the browser tab shows "Authentication complete" and
the GUI opens automatically.

The session lasts for the lifetime of the PowerShell window.  When you close
the GUI the session is disconnected automatically.

### Required Graph permissions (delegated)

| Permission | Purpose |
|------------|---------|
| `Device.Read.All` | Read Entra ID device objects |
| `User.Read.All` | Resolve the registered owner's display name and UPN |
| `DeviceManagementManagedDevices.Read.All` | Read Intune compliance and MDM state *(optional)* |

> If your account has not been granted these permissions you will see a
> consent screen the first time you run the tool.  A **Global Admin** must
> grant tenant-wide admin consent if your organisation blocks user consent.

### Custom authentication (advanced)

The included `Auth.ps1` uses interactive sign-in.  If your organisation uses
a service principal, managed identity, or a different authentication flow,
**replace** the body of `Connect-EntraDeviceTool` in `Auth.ps1`:

```powershell
# Service principal with certificate
Connect-MgGraph -ClientId $AppId -TenantId $TenantId -CertificateThumbprint $Thumb

# Managed identity (Azure VM / Automation Account)
Connect-MgGraph -Identity
```

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

## Displayed Device Attributes

| Attribute | Source in Microsoft Graph |
|-----------|--------------------------|
| Display Name | `displayName` |
| Join Type | `trustType` (friendly-formatted) |
| Registered Owner | `registeredOwners` → `displayName` |
| Owner UPN | `registeredOwners` → `userPrincipalName` |
| MDM Enrolled | `isManaged` / Intune `managementType` |
| Compliant | `isCompliant` / Intune `complianceState` |
| Intune State | Intune `complianceState` (if enrichment available) |
| Encrypted | Intune `isEncrypted` (if enrichment available) |
| Operating System | `operatingSystem` + `operatingSystemVersion` |
| Account Enabled | `accountEnabled` |
| Registration Date | `registrationDateTime` |
| Last Activity | `approximateLastSignInDateTime` |
| Stale (90+ days) | Calculated from `approximateLastSignInDateTime` |
| Device ID | `deviceId` (Entra Device ID / GUID) |
| Object ID | `id` (Entra Object ID) |

---

## Troubleshooting

### "Scripts are disabled on this system"

PowerShell's execution policy is blocking the script.  Run this once in an
Administrator PowerShell window:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Microsoft.Graph module not found"

Install the module:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

If you are behind a corporate proxy, add `-Proxy http://your-proxy:port`.

### "Authentication failed" error dialog

- Make sure you signed in with your **work / school** account (not a personal Microsoft account).
- Check that your account has been assigned the required Graph permissions.
- Try running with an explicit tenant:  
  `.\Get-EntraDeviceInfoTool.ps1 -TenantId 'contoso.onmicrosoft.com'`

### Search returns no results

- Check the **exact spelling** of the device name as it appears in the Entra portal.
- Device names are **case-insensitive** but must otherwise be exact.
- The device might not exist in Entra ID (e.g. it was deleted, or it was never registered).

### "OU Path" mode returns no results

- Confirm RSAT (`Active Directory module for Windows PowerShell`) is installed.
- Verify you have network connectivity to a domain controller.
- Check the Distinguished Name is correct (copy it from Active Directory Users and Computers).

### Excel export button does nothing

Install the `ImportExcel` module:

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

---

*Tool created from [PLAN.md](./PLAN.md) – Phase 1 implementation.*
