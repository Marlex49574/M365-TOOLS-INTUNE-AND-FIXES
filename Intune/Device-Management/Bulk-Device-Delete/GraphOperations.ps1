#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft Graph operations for the Bulk Device Delete Tool.

.DESCRIPTION
    Provides functions to find and delete device objects from Microsoft Entra ID
    (Azure AD) and Microsoft Intune via the Microsoft Graph REST API.

    Authentication must be established before calling any function here.
    Use Connect-BulkDeleteTool (Auth.ps1) or Connect-MgGraph directly.

    Key functions:
      Find-EntraDevice        – locate an Entra ID device object by display name
      Remove-EntraDevice      – delete a single device object from Entra ID
      Find-IntuneDevice       – locate an Intune managed-device record by name
      Remove-IntuneDevice     – delete a single managed-device record from Intune
      Invoke-GraphRequest     – thin throttle-safe Graph wrapper (internal helper)
#>

# ---------------------------------------------------------------------------
# Internal Graph helper
# ---------------------------------------------------------------------------

function Invoke-GraphRequest {
    <#
    .SYNOPSIS
        Thin wrapper around Invoke-MgGraphRequest with basic retry on 429/503.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet('GET','DELETE')][string]$Method = 'GET',
        [int]$MaxRetries = 3
    )
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            if ($Method -eq 'DELETE') {
                Invoke-MgGraphRequest -Method DELETE -Uri $Uri | Out-Null
                return
            }
            return Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($attempt -ge $MaxRetries -or $statusCode -notin @(429, 503)) {
                throw
            }
            $retryAfter = 2 * $attempt
            if ($_.Exception.Response.Headers -and
                $_.Exception.Response.Headers['Retry-After']) {
                $retryAfter = [int]$_.Exception.Response.Headers['Retry-After']
            }
            Write-Verbose "Graph throttled (HTTP $statusCode). Waiting ${retryAfter}s before retry $attempt/$MaxRetries."
            Start-Sleep -Seconds $retryAfter
        }
    }
}

# ---------------------------------------------------------------------------
# Entra ID (Azure AD) device operations
# ---------------------------------------------------------------------------

function Find-EntraDevice {
    <#
    .SYNOPSIS
        Returns zero or more Entra ID device objects whose displayName exactly
        matches the given computer name (case-insensitive OData filter).

    .PARAMETER Name
        Computer display name to search for.

    .OUTPUTS
        Array of PSCustomObjects with at minimum: id, deviceId, displayName.
        May be empty if the device is not found.
    #>
    param(
        [Parameter(Mandatory)][string]$Name
    )
    $encoded = [Uri]::EscapeDataString($Name)
    $uri     = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$encoded'&`$select=id,deviceId,displayName,operatingSystem,accountEnabled"
    try {
        $resp = Invoke-GraphRequest -Uri $uri
        return @($resp.value)
    } catch {
        Write-Verbose "Find-EntraDevice failed for '$Name': $_"
        return @()
    }
}

function Remove-EntraDevice {
    <#
    .SYNOPSIS
        Deletes a device object from Entra ID by its object ID.

    .PARAMETER ObjectId
        The Entra ID object ID (GUID) of the device – the 'id' property returned
        by Find-EntraDevice.

    .OUTPUTS
        $true on success, throws on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$ObjectId
    )
    $uri = "https://graph.microsoft.com/v1.0/devices/$ObjectId"
    Invoke-GraphRequest -Uri $uri -Method DELETE
    return $true
}

# ---------------------------------------------------------------------------
# Intune (managed device) operations
# ---------------------------------------------------------------------------

function Find-IntuneDevice {
    <#
    .SYNOPSIS
        Returns zero or more Intune managed-device records whose deviceName
        exactly matches the given computer name.

    .PARAMETER Name
        Computer display name to search for.

    .OUTPUTS
        Array of PSCustomObjects with at minimum: id, deviceName, azureADDeviceId.
        May be empty if the device is not Intune-enrolled.
    #>
    param(
        [Parameter(Mandatory)][string]$Name
    )
    $encoded = [Uri]::EscapeDataString($Name)
    $uri     = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq '$encoded'&`$select=id,deviceName,azureADDeviceId,complianceState,lastSyncDateTime,operatingSystem"
    try {
        $resp = Invoke-GraphRequest -Uri $uri
        return @($resp.value)
    } catch {
        Write-Verbose "Find-IntuneDevice failed for '$Name': $_"
        return @()
    }
}

function Remove-IntuneDevice {
    <#
    .SYNOPSIS
        Deletes (retires/removes) a managed-device record from Intune by its
        managed-device ID.

    .PARAMETER ManagedDeviceId
        The Intune managed-device ID (the 'id' property returned by
        Find-IntuneDevice).

    .OUTPUTS
        $true on success, throws on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$ManagedDeviceId
    )
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$ManagedDeviceId"
    Invoke-GraphRequest -Uri $uri -Method DELETE
    return $true
}
