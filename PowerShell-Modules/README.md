# PowerShell Modules

Reusable **PowerShell helper functions and modules** used across the M365 tools in this repository.

## Contents

Place shared functions, module manifests (`.psd1`), and script modules (`.psm1`) here so they can be imported from any other script in this repo.

## Recommended Modules

| Module | Install Command | Purpose |
|--------|----------------|---------|
| Microsoft.Graph | `Install-Module Microsoft.Graph` | Unified Graph API access |
| ExchangeOnlineManagement | `Install-Module ExchangeOnlineManagement` | Exchange Online PowerShell |
| Microsoft.Online.SharePoint.PowerShell | `Install-Module Microsoft.Online.SharePoint.PowerShell` | SharePoint Online management |
| MicrosoftTeams | `Install-Module MicrosoftTeams` | Teams administration |
| Microsoft.Graph.Intune | `Install-Module Microsoft.Graph.Intune` | Intune management via Graph |

## Useful Resources

- [PowerShell Gallery](https://www.powershellgallery.com/)
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/powershell/microsoftgraph/overview)
