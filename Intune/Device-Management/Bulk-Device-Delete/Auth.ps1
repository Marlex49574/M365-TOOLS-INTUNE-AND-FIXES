#Requires -Version 5.1
<#
.SYNOPSIS
    Authentication stub for the Bulk Device Delete Tool.

.DESCRIPTION
    REPLACE THIS FILE with your organisation's authentication code.

    This stub attempts a basic Connect-MgGraph with the minimum required scopes.
    For production use, replace the Connect-MgGraph call with whatever
    authentication mechanism your environment uses (device-code flow, client
    credentials, managed identity, etc.).

    Required Microsoft Graph scopes:
      - Device.ReadWrite.All                           – delete Entra ID device objects
      - DeviceManagementManagedDevices.ReadWrite.All   – delete Intune managed devices

.EXAMPLE
    # Delegated (interactive) sign-in – the default stub behaviour:
    . .\Auth.ps1
    Connect-BulkDeleteTool

    # Service-principal (unattended) – replace stub body:
    Connect-MgGraph -ClientId $AppId -TenantId $TenantId -CertificateThumbprint $Thumb
#>

function Connect-BulkDeleteTool {
    <#
    .SYNOPSIS
        Establishes an authenticated Microsoft Graph session for the Bulk Device Delete Tool.

    .PARAMETER Scopes
        Array of Microsoft Graph permission scopes to request.
        Defaults to the minimum set required by this tool.

    .PARAMETER TenantId
        Optional. Azure AD tenant ID or domain name. If omitted, Connect-MgGraph
        will prompt the user to select from their available tenants.
    #>
    param(
        [string[]]$Scopes = @(
            'Device.ReadWrite.All',
            'DeviceManagementManagedDevices.ReadWrite.All'
        ),
        [string]$TenantId = $null
    )

    # Ensure the Microsoft.Graph module is available
    if (-not (Get-Module -Name Microsoft.Graph.Authentication -ListAvailable)) {
        Write-Host 'Microsoft.Graph module not found. Installing…' -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $connectParams = @{ Scopes = $Scopes }
    if ($TenantId) { $connectParams['TenantId'] = $TenantId }

    Write-Host 'Connecting to Microsoft Graph…' -ForegroundColor Cyan
    Connect-MgGraph @connectParams -ErrorAction Stop

    $ctx = Get-MgContext
    Write-Host "Connected as: $($ctx.Account) | Tenant: $($ctx.TenantId)" -ForegroundColor Green
}

function Disconnect-BulkDeleteTool {
    <#
    .SYNOPSIS
        Disconnects the current Microsoft Graph session.
    #>
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Write-Host 'Disconnected from Microsoft Graph.' -ForegroundColor Yellow
}
