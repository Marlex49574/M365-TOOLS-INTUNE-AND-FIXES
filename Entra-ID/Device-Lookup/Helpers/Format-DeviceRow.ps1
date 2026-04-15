#Requires -Version 5.1
<#
.SYNOPSIS
    Maps raw Microsoft Graph device objects to display-friendly strings.

.DESCRIPTION
    Provides helper functions that convert Graph API response properties
    (booleans, ISO date strings, trust type codes, etc.) to human-readable
    labels and emoji indicators used in the DataGridView and detail panel.
#>

# Number of days without a sign-in after which a device is considered stale.
# Override by setting $Script:StaleDeviceDays before dot-sourcing this file.
if (-not (Get-Variable -Name StaleDeviceDays -Scope Script -ErrorAction SilentlyContinue)) {
    $Script:StaleDeviceDays = 90
}

function Format-JoinType {
    <#
    .SYNOPSIS
        Converts a trustType string from the Graph API to a readable label.
    #>
    param([string]$TrustType)
    switch ($TrustType) {
        'AzureAD'   { return 'AAD Joined' }
        'ServerAD'  { return 'Hybrid AAD Joined' }
        'Workplace' { return 'Workplace Registered' }
        default     { if ($TrustType) { return $TrustType } else { return '—' } }
    }
}

function Format-BoolIcon {
    <#
    .SYNOPSIS
        Converts a boolean (or $null) value to a coloured icon string.
    .PARAMETER Value
        The boolean value to format. Pass $null for unknown.
    .PARAMETER TrueLabel
        Icon to use when Value is $true. Defaults to '✅'.
    .PARAMETER FalseLabel
        Icon to use when Value is $false. Defaults to '❌'.
    .PARAMETER NullLabel
        String to use when Value is $null. Defaults to '—'.
    #>
    param(
        [object]$Value,
        [string]$TrueLabel  = '✅',
        [string]$FalseLabel = '❌',
        [string]$NullLabel  = '—'
    )
    if ($null -eq $Value) { return $NullLabel }
    if ($Value -eq $true) { return $TrueLabel }
    return $FalseLabel
}

function Format-DateTime {
    <#
    .SYNOPSIS
        Parses an ISO 8601 date string returned by Graph and returns a
        human-readable local-time string. Returns '—' if the input is null/empty.
    #>
    param([string]$DateString)
    if ([string]::IsNullOrWhiteSpace($DateString)) { return '—' }
    try {
        $dt = [datetime]::Parse(
            $DateString,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        )
        return $dt.ToLocalTime().ToString('yyyy-MM-dd HH:mm')
    } catch {
        return $DateString
    }
}

function Test-StaleDevice {
    <#
    .SYNOPSIS
        Returns $true when the device has had no sign-in activity for
        $Script:StaleDeviceDays or more days (default: 90).
    #>
    param([string]$LastActivityDateString)
    if ([string]::IsNullOrWhiteSpace($LastActivityDateString)) { return $false }
    try {
        $dt = [datetime]::Parse(
            $LastActivityDateString,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        )
        return ([datetime]::UtcNow - $dt.ToUniversalTime()).TotalDays -ge $Script:StaleDeviceDays
    } catch {
        return $false
    }
}

function Format-DeviceRow {
    <#
    .SYNOPSIS
        Converts a raw Microsoft Graph device object to a flat, display-friendly
        ordered hashtable suitable for a DataGridView row.

    .PARAMETER Device
        The PSCustomObject returned by the Graph 'devices' endpoint.

    .PARAMETER Owner
        Optional. The PSCustomObject returned by 'devices/<id>/registeredOwners'.

    .PARAMETER Intune
        Optional. The PSCustomObject returned by 'deviceManagement/managedDevices'.

    .OUTPUTS
        [ordered] hashtable with display columns (visible in the grid) and
        hidden/raw columns prefixed with '_' (used by the detail panel and
        row colour-coding logic).
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Device,
        [PSCustomObject]$Owner  = $null,
        [PSCustomObject]$Intune = $null
    )

    # Owner display string
    $ownerDisplay = if ($Owner -and $Owner.displayName)      { $Owner.displayName }
                    elseif ($Owner -and $Owner.userPrincipalName) { $Owner.userPrincipalName }
                    else { '—' }

    # MDM / management status
    $mdmDisplay = if ($null -ne $Intune) {
        '✅'   # Intune record exists → enrolled
    } elseif ($Device.isManaged -eq $true) {
        '✅'
    } elseif ($Device.isManaged -eq $false) {
        '❌'
    } else {
        '—'
    }

    # Compliance state
    $compliantDisplay = if ($null -ne $Intune -and $Intune.complianceState) {
        if ($Intune.complianceState -eq 'compliant') { '✅' } else { "❌ $($Intune.complianceState)" }
    } elseif ($null -ne $Device.isCompliant) {
        Format-BoolIcon -Value $Device.isCompliant
    } else {
        '—'
    }

    # OS column
    $osParts   = @($Device.operatingSystem, $Device.operatingSystemVersion) | Where-Object { $_ }
    $osDisplay = if ($osParts) { $osParts -join ' ' } else { '—' }

    [ordered]@{
        # ── Visible grid columns ──────────────────────────────────────────
        'Name'         = if ($Device.displayName) { $Device.displayName } else { '—' }
        'Join Type'    = Format-JoinType -TrustType $Device.trustType
        'Owner'        = $ownerDisplay
        'MDM Enrolled' = $mdmDisplay
        'Compliant'    = $compliantDisplay
        'OS'           = $osDisplay
        'Enabled'      = Format-BoolIcon -Value $Device.accountEnabled
        'Reg. Date'    = Format-DateTime -DateString $Device.registrationDateTime
        'Last Active'  = Format-DateTime -DateString $Device.approximateLastSignInDateTime
        # ── Hidden / raw columns (prefixed _) ─────────────────────────────
        '_DeviceId'       = $Device.deviceId
        '_ObjectId'       = $Device.id
        '_TrustType'      = $Device.trustType
        '_isCompliant'    = $Device.isCompliant
        '_isManaged'      = $Device.isManaged
        '_accountEnabled' = $Device.accountEnabled
        '_OwnerUPN'       = if ($Owner) { $Owner.userPrincipalName } else { $null }
        '_OwnerName'      = if ($Owner) { $Owner.displayName } else { $null }
        '_IntuneState'    = if ($Intune) { $Intune.complianceState } else { $null }
        '_IntuneEncrypt'  = if ($Intune) { $Intune.isEncrypted } else { $null }
        '_OS'             = $Device.operatingSystem
        '_OSVersion'      = $Device.operatingSystemVersion
        '_LastActivity'   = $Device.approximateLastSignInDateTime
        '_IsStale'        = Test-StaleDevice -LastActivityDateString $Device.approximateLastSignInDateTime
    }
}
