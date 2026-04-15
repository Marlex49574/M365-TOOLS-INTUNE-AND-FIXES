#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft Graph query functions for the Entra ID Device Info Lookup Tool.

.DESCRIPTION
    Provides functions to retrieve device objects, their registered owners, and
    optional Intune enrichment data from Microsoft Graph.

    Authentication is handled externally: call Connect-MgGraph (or equivalent)
    before invoking any function in this file.

    Key functions:
      Get-DeviceByName        – single device lookup by displayName
      Get-DevicesByNames      – bulk lookup for a list of names (throttle-safe)
      Get-DevicesInGroup      – all devices in a named Entra group
      Get-DevicesByOU         – hybrid: fetch computer names from on-prem AD, then
                                enrich each with Entra data
      Get-DeviceOwner         – registered owner(s) for a single device object ID
      Get-DeviceIntuneDetails – Intune managed-device record for a device ID
      Get-DeviceDetails       – convenience wrapper: device + owner + Intune in one call
#>

# ---------------------------------------------------------------------------
# Graph query helpers
# ---------------------------------------------------------------------------

# Fields to request for every device query (minimises payload size)
$Script:DeviceSelect = @(
    'id', 'deviceId', 'displayName', 'trustType',
    'operatingSystem', 'operatingSystemVersion',
    'isCompliant', 'isManaged', 'accountEnabled',
    'registrationDateTime', 'approximateLastSignInDateTime'
) -join ','

function Invoke-GraphRequest {
    <#
    .SYNOPSIS
        Thin wrapper around Invoke-MgGraphRequest with basic retry on 429/503.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int]$MaxRetries = 3
    )
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($attempt -ge $MaxRetries -or $statusCode -notin @(429, 503)) {
                throw
            }
            # Back-off: respect Retry-After header when present
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

function Get-DeviceByName {
    <#
    .SYNOPSIS
        Returns zero or more Entra ID device objects whose displayName matches the
        given name. Uses a case-insensitive 'startsWith' or 'eq' filter.

    .PARAMETER Name
        The device display name to search for (exact match).

    .OUTPUTS
        An array of PSCustomObject device records (may be empty).
    #>
    param(
        [Parameter(Mandatory)][string]$Name
    )
    $encoded = [Uri]::EscapeDataString($Name)
    $uri     = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$encoded'&`$select=$Script:DeviceSelect"
    $resp    = Invoke-GraphRequest -Uri $uri
    return @($resp.value)
}

function Get-DevicesByNames {
    <#
    .SYNOPSIS
        Bulk-queries Entra ID for a list of device display names.
        Queries are batched in groups of up to 15 (Graph OData 'in' filter limit)
        and run sequentially to stay within throttle limits.

    .PARAMETER Names
        Array of device display names to look up.

    .OUTPUTS
        Array of PSCustomObject device records for all found devices.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Names
    )
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $batchSize = 15

    for ($i = 0; $i -lt $Names.Count; $i += $batchSize) {
        $batch = $Names[$i..([Math]::Min($i + $batchSize - 1, $Names.Count - 1))]

        if ($batch.Count -eq 1) {
            # Single name – use eq filter (more reliable)
            $items = Get-DeviceByName -Name $batch[0]
        } else {
            # Multiple names – use 'in' operator
            $inList = ($batch | ForEach-Object { "'$([Uri]::EscapeDataString($_))'" }) -join ','
            $uri    = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName in ($inList)&`$select=$Script:DeviceSelect"
            try {
                $resp  = Invoke-GraphRequest -Uri $uri
                $items = @($resp.value)
            } catch {
                Write-Warning "Batch query failed for names [$($batch -join ', ')]: $_"
                # Fall back to individual queries for this batch
                $items = foreach ($n in $batch) {
                    try { Get-DeviceByName -Name $n } catch { Write-Warning "Failed for '$n': $_" }
                }
            }
        }

        foreach ($item in $items) { $results.Add($item) }

        # Small delay between batches to avoid aggressive throttling
        if ($i + $batchSize -lt $Names.Count) { Start-Sleep -Milliseconds 200 }
    }

    return $results.ToArray()
}

function Get-DevicesInGroup {
    <#
    .SYNOPSIS
        Returns all device members of an Entra ID group, looked up by group display name.

    .PARAMETER GroupName
        The display name of the Entra ID group.

    .OUTPUTS
        Array of PSCustomObject device records.
    #>
    param(
        [Parameter(Mandatory)][string]$GroupName
    )

    # Find the group
    $encoded  = [Uri]::EscapeDataString($GroupName)
    $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$encoded'&`$select=id,displayName"
    $groupResp = Invoke-GraphRequest -Uri $groupUri
    if (-not $groupResp.value -or $groupResp.value.Count -eq 0) {
        Write-Warning "Group '$GroupName' not found in Entra ID."
        return @()
    }
    $groupId = $groupResp.value[0].id

    # Retrieve device members (may be paged)
    $devices = [System.Collections.Generic.List[PSCustomObject]]::new()
    $membersUri = "https://graph.microsoft.com/v1.0/groups/$groupId/members/microsoft.graph.device?`$select=$Script:DeviceSelect"

    while ($membersUri) {
        $resp = Invoke-GraphRequest -Uri $membersUri
        foreach ($d in $resp.value) { $devices.Add($d) }
        $membersUri = $resp.'@odata.nextLink'
    }

    return $devices.ToArray()
}

function Get-DevicesByOU {
    <#
    .SYNOPSIS
        (Hybrid environments) Retrieves computer names from an on-premises Active
        Directory OU, then enriches each with Entra ID data.

    .PARAMETER OUDistinguishedName
        The OU distinguished name, e.g. 'OU=Workstations,DC=contoso,DC=com'.

    .OUTPUTS
        Array of PSCustomObject device records (Entra ID enriched).

    .NOTES
        Requires the ActiveDirectory PowerShell module (RSAT).
        Returns an empty array with a warning in cloud-only environments.
    #>
    param(
        [Parameter(Mandatory)][string]$OUDistinguishedName
    )

    if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
        Write-Warning "The 'ActiveDirectory' module is not available. OU-based lookup requires RSAT on a domain-joined machine."
        return @()
    }

    try {
        $computers = Get-ADComputer -SearchBase $OUDistinguishedName -Filter * -Properties Name |
            Select-Object -ExpandProperty Name
    } catch {
        Write-Warning "Failed to query AD OU '$OUDistinguishedName': $_"
        return @()
    }

    if (-not $computers) {
        Write-Warning "No computer objects found in OU: $OUDistinguishedName"
        return @()
    }

    return Get-DevicesByNames -Names $computers
}

function Get-DeviceOwner {
    <#
    .SYNOPSIS
        Returns the first registered owner of a device (by Entra device object ID).

    .PARAMETER DeviceObjectId
        The Entra ID object ID (GUID) of the device, not the deviceId.

    .OUTPUTS
        A single PSCustomObject with displayName and userPrincipalName, or $null.
    #>
    param(
        [Parameter(Mandatory)][string]$DeviceObjectId
    )
    try {
        $uri  = "https://graph.microsoft.com/v1.0/devices/$DeviceObjectId/registeredOwners?`$select=displayName,userPrincipalName"
        $resp = Invoke-GraphRequest -Uri $uri
        if ($resp.value -and $resp.value.Count -gt 0) {
            return $resp.value[0]
        }
    } catch {
        Write-Verbose "Could not retrieve owner for device $DeviceObjectId : $_"
    }
    return $null
}

function Get-DeviceIntuneDetails {
    <#
    .SYNOPSIS
        Returns the Intune managed-device record for a given Entra deviceId (GUID).
        This record adds complianceState, isEncrypted, and other MDM fields.

    .PARAMETER DeviceId
        The Entra device ID (the 'deviceId' property, not the object ID).

    .OUTPUTS
        A PSCustomObject with Intune properties, or $null if not found /
        insufficient permissions.
    #>
    param(
        [Parameter(Mandatory)][string]$DeviceId
    )
    try {
        $encoded = [Uri]::EscapeDataString($DeviceId)
        $uri     = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$encoded'&`$select=id,azureADDeviceId,complianceState,isEncrypted,managedDeviceName,lastSyncDateTime"
        $resp    = Invoke-GraphRequest -Uri $uri
        if ($resp.value -and $resp.value.Count -gt 0) {
            return $resp.value[0]
        }
    } catch {
        Write-Verbose "Could not retrieve Intune details for deviceId $DeviceId : $_"
    }
    return $null
}

function Get-DeviceDetails {
    <#
    .SYNOPSIS
        Convenience wrapper: retrieves a single device by name together with its
        registered owner and optional Intune enrichment.

    .PARAMETER Name
        The device display name.

    .PARAMETER IncludeIntune
        When specified, also queries Intune for MDM/compliance data.

    .OUTPUTS
        An array of [hashtable] objects, each containing:
          Device  – raw Graph device object
          Owner   – registered owner (or $null)
          Intune  – Intune managed-device record (or $null)
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$IncludeIntune
    )
    $devices = Get-DeviceByName -Name $Name
    $results = foreach ($device in $devices) {
        $owner  = Get-DeviceOwner -DeviceObjectId $device.id
        $intune = if ($IncludeIntune -and $device.deviceId) {
            Get-DeviceIntuneDetails -DeviceId $device.deviceId
        } else { $null }

        @{
            Device = $device
            Owner  = $owner
            Intune = $intune
        }
    }
    return $results
}
