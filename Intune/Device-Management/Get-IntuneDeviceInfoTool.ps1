#Requires -Version 5.1
<#
.SYNOPSIS
    Data functions for querying Intune managed devices from Microsoft Graph.

.DESCRIPTION
    Defines helper functions for fetching Intune device information via the
    Microsoft Graph API. This file is dot-sourced by the M365 Tool Portal
    (BASE/MAIN/Start-M365ToolPortal.ps1) and can also be used in standalone scripts.

    Functions provided:
      Invoke-IntuneGraphRequest   - HTTP GET wrapper with retry logic
      Get-IntuneManagedDeviceInfo - Search devices by name, user, or serial number
      Get-IntuneDisplayValue      - Safely converts a nullable value to string

.NOTES
    Requires an active Microsoft Graph context (Connect-MgGraph) before calling
    Get-IntuneManagedDeviceInfo. Dot-source this file to load the functions:
      . .\Get-IntuneDeviceInfoTool.ps1
#>

function Invoke-IntuneGraphRequest {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int]$MaxRetries = 3
    )

    $attempt = 0
    $httpNotImplemented = 501
    while ($true) {
        $attempt++
        try {
            return Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            # HTTP 501 (Not Implemented) indicates unsupported operation and is not expected to succeed on retry.
            $isTransientServerError = ($statusCode -ge 500 -and $statusCode -le 599 -and $statusCode -ne $httpNotImplemented)
            if ($attempt -ge $MaxRetries -or (-not $isTransientServerError -and $statusCode -notin @(429, 503))) {
                throw
            }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Get-IntuneManagedDeviceInfo {
    param(
        [Parameter(Mandatory)][string]$SearchText,
        [ValidateRange(1, 500)][int]$PageSize = 200
    )

    $safeSearch = $SearchText.Trim()
    if ($safeSearch -notmatch "^[a-zA-Z0-9@\.\-_ ]+$") {
        throw "Search text contains invalid characters. Only letters, numbers, spaces, and these special characters are allowed: @ . - _"
    }

    if (-not (Get-Module -Name Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    }

    $filter = "startswith(displayName,'$safeSearch')"
    $devices = Get-MgDevice -Filter $filter -Top $PageSize -ExpandProperty registeredOwners -ErrorAction Stop

    $results = foreach ($dev in $devices) {
        # Parse serial number from PhysicalIds (entries look like "[SerialNumber]:XXXX")
        $serial = ($dev.PhysicalIds | Where-Object { $_ -like '[SerialNumber]:*' } | Select-Object -First 1) -replace '^\[SerialNumber\]:', ''

        # Get primary user UPN from the first registered owner
        $upn = ''
        if ($dev.RegisteredOwners -and $dev.RegisteredOwners.Count -gt 0) {
            $owner = $dev.RegisteredOwners[0]
            if ($owner.AdditionalProperties -and $owner.AdditionalProperties['userPrincipalName']) {
                $upn = $owner.AdditionalProperties['userPrincipalName']
            }
        }

        [PSCustomObject]@{
            deviceName        = $dev.DisplayName
            userPrincipalName = $upn
            operatingSystem   = $dev.OperatingSystem
            osVersion         = $dev.OperatingSystemVersion
            complianceState   = 'N/A'
            lastSyncDateTime  = $dev.ApproximateLastSignInDateTime
            managementAgent   = switch ($dev.ManagementType) {
                'mdm'         { 'Intune' }
                'easMdm'      { 'Intune (EAS)' }
                'intuneClient' { 'Intune' }
                'configurationManagerClientMdm' { 'Co-managed' }
                'configurationManagerClientMdmEas' { 'Co-managed (EAS)' }
                'eas'         { 'EAS' }
                default       { if ($dev.ManagementType) { $dev.ManagementType } else { 'Unknown' } }
            }
            serialNumber      = $serial
            manufacturer      = $dev.Manufacturer
            model             = $dev.Model
            deviceId          = $dev.DeviceId
            objectId          = $dev.Id
            enrolledDateTime  = $null
        }
    }

    return @($results)
}

function Get-IntuneDisplayValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    return [string]$Value
}
