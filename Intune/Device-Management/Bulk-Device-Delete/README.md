# Bulk Device Delete Tool

Delete computer accounts from **Local Active Directory**, **Microsoft Entra ID (Azure AD)**, and **Microsoft Intune** in a single operation by supplying a CSV file of computer names.

---

## Features

| Feature | Detail |
|---|---|
| **CSV Import** | Accepts any CSV with a `ComputerName`, `Name`, `DeviceName`, `Computer`, `Hostname`, or `Host` column. Falls back to the first column. |
| **Selective Targets** | Choose any combination of Local AD / Entra ID / Intune per run |
| **Preview** | Look up each device across all selected targets _before_ deleting |
| **Confirmation** | Mandatory Yes/No prompt before any deletion is performed |
| **Live Status Grid** | Per-device, per-target status (Found · Deleted · NotFound · Error) |
| **Colour-coded Log** | Scrollable real-time output log with green/amber/red colouring |
| **Export Log** | Save the full result set to a timestamped CSV |
| **Dark / Light Theme** | Toggle in the top-right corner |

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Windows PowerShell 5.1** or **PowerShell 7+** | Required for WinForms |
| **Microsoft.Graph** PS module | Installed automatically if missing (`Install-Module Microsoft.Graph`) |
| **RSAT – Active Directory** module | Required _only_ for Local AD deletion. Install via `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` |
| **Domain-joined machine** (or DC connectivity) | Required for Local AD operations |
| **Graph permissions** | `Device.ReadWrite.All` + `DeviceManagementManagedDevices.ReadWrite.All` |

---

## Quick Start

```powershell
# Interactive sign-in (browser prompt)
.\Remove-DeviceBulkTool.ps1

# Specify tenant explicitly
.\Remove-DeviceBulkTool.ps1 -TenantId 'contoso.onmicrosoft.com'

# Skip authentication (Graph session already open)
.\Remove-DeviceBulkTool.ps1 -SkipConnect
```

---

## CSV Format

The CSV file must have **one computer name per row**. Accepted column headers (case-insensitive):

```
ComputerName, Name, DeviceName, Computer, Hostname, Host
```

If none of these headers exist, the **first column** is used.

**Example:**

```csv
ComputerName
PC-001
PC-002
LAPTOP-FINANCE-03
```

---

## Workflow

1. **Browse** → select your CSV file  
2. **Load List** → imports and displays all computer names  
3. *(Optional)* **Preview** → queries AD / Entra / Intune and shows what was found without deleting  
4. Select targets with the checkboxes (AD · Entra ID · Intune)  
5. **Delete All** → confirmation prompt → deletion runs with live status updates  
6. **Export Log** → saves a CSV with `ComputerName, Target, Status, Message, Timestamp`

---

## File Layout

```
Bulk-Device-Delete/
├── Remove-DeviceBulkTool.ps1   ← entry point (run this)
├── Auth.ps1                     ← authentication stub (customise for your org)
├── GraphOperations.ps1          ← Entra ID + Intune Graph API functions
├── ADOperations.ps1             ← Local Active Directory functions
├── UI/
│   ├── Theme.ps1                ← Fluent-inspired Dark/Light palette
│   └── MainForm.ps1             ← WinForms GUI
└── Helpers/
    ├── Import-DeviceList.ps1    ← CSV parser
    └── Export-Results.ps1       ← CSV export helper
```

---

## Customising Authentication

`Auth.ps1` is a replaceable stub. For unattended / service-principal authentication, replace the body of `Connect-BulkDeleteTool` with your organisation's sign-in method:

```powershell
# Certificate-based service principal example
Connect-MgGraph -ClientId $AppId -TenantId $TenantId -CertificateThumbprint $Thumb
```

---

## Notes

* **Deletion is permanent.** The Preview step is strongly recommended before running Delete.
* If a computer appears in Entra ID under multiple object IDs (e.g. hybrid-join duplicates), **all** matching objects are deleted.
* Local AD deletion requires the account running the script to have permission to delete computer objects in the relevant OU (typically Domain Admins or delegated rights).
* Intune-managed devices are removed via the `DELETE /deviceManagement/managedDevices/{id}` endpoint (equivalent to a "Delete" action in the Intune portal).
