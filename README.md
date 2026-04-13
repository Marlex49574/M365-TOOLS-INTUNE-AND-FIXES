# M365 Tools – Intune and Fixes

A collection of scripts, tools, and fixes for administering **Microsoft 365** environments.

## Folder Structure

| Folder | Description |
|--------|-------------|
| [Intune](./Intune/) | Device management, app deployment, compliance, configuration profiles, and enrollment |
| [Entra-ID](./Entra-ID/) | User and group management, Conditional Access, app registrations, and RBAC |
| [User-Administration](./User-Administration/) | Onboarding, offboarding, bulk operations, and license management |
| [Exchange-Online](./Exchange-Online/) | Mail flow, distribution groups, shared mailboxes, and anti-spam/phishing |
| [SharePoint-Online](./SharePoint-Online/) | Site management and permissions |
| [Teams](./Teams/) | Policies and meeting settings |
| [Security](./Security/) | Microsoft Defender, DLP policies, and threat protection |
| [PowerShell-Modules](./PowerShell-Modules/) | Shared helper functions and reusable PowerShell modules |

## Prerequisites

Most scripts in this repository use one or more of the following PowerShell modules:

```powershell
Install-Module Microsoft.Graph
Install-Module ExchangeOnlineManagement
Install-Module MicrosoftTeams
Install-Module Microsoft.Online.SharePoint.PowerShell
```

## Contributing

1. Place scripts in the most relevant subfolder.
2. Include a brief comment header in each script describing its purpose, parameters, and usage example.
3. Update the subfolder `README.md` with a short description of any new script you add.
