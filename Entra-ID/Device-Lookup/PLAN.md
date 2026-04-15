# Plan – Entra ID Device Info Lookup Tool

## Overview

A **PowerShell / Windows Forms** GUI tool that lets an administrator look up one or more
computer objects in Microsoft Entra ID (formerly Azure AD) and displays all relevant device
details in a clean, modern dashboard view.

---

## Goals

| # | Goal |
|---|------|
| 1 | Enter a **single computer name**, a **comma- or newline-separated list of computer names**, or an **OU / Organizational-Unit path** and retrieve every matching Entra ID device object. |
| 2 | Display a rich set of device attributes in a well-structured, modern GUI. |
| 3 | Export results to CSV / Excel or copy them to the clipboard. |
| 4 | Provide live status feedback (progress bar, spinner, status bar text). |
| 5 | Work with any existing Graph/Entra authentication flow (authentication code will be provided separately). |

---

## Core Device Attributes to Display

| Column | Source |
|--------|--------|
| Display Name | `displayName` |
| Join Type | `joinType` (`AzureADJoined`, `HybridAzureADJoined`, `RegisteredDevice`) |
| Owner / Registered Owner | `registeredOwners` |
| MDM Enrolled | `isManaged` / `managementType` |
| Security Settings Management | `deviceGuardLocalSystemAuthorityCredentialGuardState` / `isCompliant` related |
| Compliant State | `isCompliant` |
| Operating System & Version | `operatingSystem`, `operatingSystemVersion` |
| Registration Date | `registrationDateTime` |
| Last Activity Date | `approximateLastSignInDateTime` |
| Entra ID Device ID | `deviceId` |
| Object ID | `id` |
| Enabled State | `accountEnabled` |
| Trust Type | `trustType` |

---

## GUI Layout & Design

### Main Window

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  🔵  Entra ID – Device Info Lookup                          [─] [□] [✕]    │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌── Search ──────────────────────────────────────────────────────────────┐ │
│  │  Mode:  ● Computer Name(s)   ○ OU Path                                │ │
│  │                                                                        │ │
│  │  Input: [________________________________________________] [Search 🔍] │ │
│  │         (comma-separated names or one per line)                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌── Results ─────────────────────────────────────────────────────────────┐ │
│  │  [DataGridView – sortable, resizable columns, alternating row color]   │ │
│  │                                                                        │ │
│  │  Name | Join Type | Owner | MDM | Compliant | Reg. Date | Last Active  │ │
│  │  ───────────────────────────────────────────────────────────────────── │ │
│  │  PC-001 │ AAD Joined │ john@… │ ✅ │ ✅ │ 2024-01-15 │ 2026-04-10    │ │
│  │  PC-002 │ Hybrid     │ —      │ ❌ │ ⚠️ │ 2023-06-01 │ 2026-03-28    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌── Detail Panel (click a row) ──────────────────────────────────────────┐ │
│  │  [Left: Key-Value list of ALL attributes for the selected device]      │ │
│  │  [Right: Quick-action buttons: Open in Entra Portal | Copy ID]        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  [Export CSV]  [Export Excel]  [Copy Table]   Status: Ready  [▓░░░░░] 0%  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Colour Scheme (Modern Dark/Light Toggle)

- **Background:** `#1E1E2E` (dark) / `#F5F7FA` (light)
- **Accent:** `#0078D4` (Microsoft Blue)
- **Success:** `#107C10` (green)
- **Warning / Non-compliant:** `#CA5010` (orange)
- **Font:** Segoe UI 10pt (Windows default modern font)
- Icons use Unicode emoji / Segoe MDL2 Assets glyphs for ✅ ❌ ⚠️ indicators

---

## Feature List

### Must-Have (Phase 1)

- [x] **Single computer name lookup** – type a name, press Search, see results instantly.
- [x] **Bulk lookup** – paste a comma-separated or newline-separated list of names.
- [x] **OU-based lookup** – enter an OU distinguished name; the tool queries all computer
      objects in that OU (requires on-premises AD + Graph for Hybrid scenarios, or a
      device group / filter in cloud-only setups).
- [x] **Result grid** – sortable, filterable `DataGridView` with colour-coded cells
      (compliant = green, non-compliant = orange/red, disabled = grey).
- [x] **Detail panel** – click any row to expand all attributes in a side/bottom panel.
- [x] **CSV export** – one click to save the current result set as a `.csv` file.
- [x] **Copy to clipboard** – copies the visible grid as tab-separated text.
- [x] **Status bar** – shows last-refresh time, number of results, and any errors.
- [x] **Progress / busy indicator** – shows while Graph queries are running.

### Nice-to-Have (Phase 2)

- [ ] **Excel export** – using the `ImportExcel` module or COM automation to produce a
      formatted `.xlsx` with bold headers and auto-column widths.
- [ ] **Dark / Light mode toggle** – button or system-preference detection.
- [ ] **Quick search / filter box** – client-side filter on the already-loaded result set
      without re-querying Graph.
- [ ] **Open in Entra Portal** – right-click any device row → open
      `https://entra.microsoft.com/#view/…/device/<objectId>` in the default browser.
- [ ] **Refresh selected** – re-query only the selected rows to see up-to-date info
      without a full search.
- [ ] **Stale device highlight** – devices with no sign-in in 90+ days highlighted in yellow.
- [ ] **Disable / Enable device action** – admin shortcut to toggle `accountEnabled`
      directly from the tool (requires `Device.ReadWrite.All` permission).
- [ ] **Delete device action** – with confirmation dialog.
- [ ] **Column picker** – let the admin hide/show specific columns.
- [ ] **Saved searches** – remember the last 10 searches in a local JSON config file.
- [ ] **Keyboard shortcuts** – `F5` = refresh, `Ctrl+E` = export, `Ctrl+F` = filter.
- [ ] **Settings panel** – configurable timeout, max results per query, OU path presets.
- [ ] **Multi-tenant support** – dropdown to switch between saved tenant connections
      (for MSP admins managing many tenants).

---

## Technical Architecture

```
Get-EntraDeviceInfoTool.ps1   ← entry-point / bootstrapper
│
├── Auth.ps1                  ← (provided by user) Connect to Graph / token handling
├── GraphQueries.ps1          ← functions: Get-DeviceByName, Get-DevicesByOU, etc.
├── UI\
│   ├── MainForm.ps1          ← builds the WinForms window, all controls
│   ├── DetailPanel.ps1       ← builds the expandable detail view
│   └── Theme.ps1             ← colour constants and helper: Set-Theme, Apply-Theme
└── Helpers\
    ├── Export-Results.ps1    ← CSV / Excel export functions
    └── Format-DeviceRow.ps1  ← maps raw Graph JSON to display-friendly strings
```

### PowerShell Modules Required

| Module | Purpose |
|--------|---------|
| `Microsoft.Graph.Identity.DirectoryManagement` | Query `GET /devices` endpoint |
| `Microsoft.Graph.DeviceManagement` (optional) | Enrich with Intune compliance data |
| `ImportExcel` (optional, phase 2) | Excel export |

> **Note:** All Graph calls will use the authentication token / session already
> established by the caller-provided `Auth.ps1`. No new authentication logic will be
> added inside this tool.

### Graph API Calls Planned

```
# Single device by display name
GET /devices?$filter=displayName eq 'PC-001'&$select=id,deviceId,displayName,operatingSystem,...

# Bulk lookup (parallel, throttle-friendly)
GET /devices?$filter=displayName in ('PC-001','PC-002')&$select=...

# OU-based (Hybrid – from on-prem AD, then enrich via Graph)
Get-ADComputer -SearchBase "OU=Workstations,DC=contoso,DC=com" -Filter * |
  ForEach-Object { GET /devices?$filter=displayName eq '<name>' }

# Registered owner
GET /devices/<id>/registeredOwners?$select=displayName,userPrincipalName

# Intune compliance
GET /deviceManagement/managedDevices?$filter=azureADDeviceId eq '<deviceId>'&$select=complianceState,isEncrypted,...
```

---

## File & Folder Location in This Repo

```
Entra-ID/
└── Device-Lookup/
    ├── PLAN.md                        ← this document
    ├── Get-EntraDeviceInfoTool.ps1    ← main launcher (Phase 2)
    ├── README.md                      ← usage instructions (Phase 2)
    └── … (sub-files per architecture above)
```

---

## Open Questions / Things to Clarify Before Coding

1. **Authentication** – What cmdlet / flow does the existing auth code use?
   (`Connect-MgGraph`? `Connect-AzAccount`? Custom token cache?) This determines how
   `Auth.ps1` will be plugged in.
2. **OU Lookup** – Is this a Hybrid (on-prem AD) environment or cloud-only?
   Cloud-only tenants have no OU concept; we would use **device groups** or
   **dynamic filters** instead. Should both modes be supported?
3. **Permissions** – Will the tool run under a delegated user context or an
   app-registration service principal? This affects which Graph scopes need to be
   consented.
4. **Intune enrichment** – Should the Intune compliance/MDM details come from
   `GET /deviceManagement/managedDevices` (requires additional Graph scope) or is the
   Entra ID `isManaged`/`isCompliant` field sufficient?
5. **Target OS** – Windows 10/11 only (for WinForms), or does it need to run on Windows
   Server as well?
6. **Deployment method** – Run directly from a network share, packaged as a `.exe`
   (PS2EXE), or distributed via Intune as a Win32 app?

---

## Development Phases

### Phase 1 – Core Tool (implement first)
1. Build the WinForms skeleton with the search bar, result grid, and status bar.
2. Wire up `Get-DeviceByName` Graph query.
3. Implement bulk name lookup with parallel/throttled Graph calls.
4. Add detail panel.
5. Add CSV export and clipboard copy.
6. Basic colour-coding in the grid (compliant / non-compliant / disabled).

### Phase 2 – Enhancements
1. OU-based lookup (on-prem AD or cloud group).
2. Dark/Light theme toggle.
3. Excel export.
4. Open-in-portal action.
5. Stale device highlighting.
6. Saved searches & settings panel.

### Phase 3 – Admin Actions (optional, needs elevated permissions)
1. Enable / Disable device.
2. Delete device.
3. Trigger Intune sync.

---

*Plan created: 2026-04-15 | Author: @copilot*
