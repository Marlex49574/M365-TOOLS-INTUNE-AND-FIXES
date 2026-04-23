#Requires -Version 5.1
<#
.SYNOPSIS
    Local Active Directory operations for the Bulk Device Delete Tool.

.DESCRIPTION
    Provides functions to find and delete computer objects from a local
    (on-premises) Active Directory domain.

    Requires:
      - The ActiveDirectory PowerShell module (part of RSAT on Windows).
      - The machine running this tool must be domain-joined, or have
        connectivity to a domain controller with the necessary rights.

    Key functions:
      Find-ADComputerObject   – locate a computer object by name
      Remove-ADComputerObject – delete a computer object from AD
      Test-ADModuleAvailable  – checks whether RSAT AD module is present
#>

function Test-ADModuleAvailable {
    <#
    .SYNOPSIS
        Returns $true if the ActiveDirectory module is loadable, $false otherwise.
    #>
    return ($null -ne (Get-Module -Name ActiveDirectory -ListAvailable))
}

function Find-ADComputerObject {
    <#
    .SYNOPSIS
        Searches local Active Directory for a computer account by name.

    .PARAMETER Name
        The sAMAccountName / computer name (without trailing $).

    .OUTPUTS
        A Microsoft.ActiveDirectory.Management.ADComputer object, or $null if
        not found or the AD module is unavailable.
    #>
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Test-ADModuleAvailable)) {
        Write-Verbose "ActiveDirectory module not available. Skipping AD lookup for '$Name'."
        return $null
    }

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        # Strip any stray BOM or whitespace the CSV may have introduced
        $cleanName = $Name.Trim().TrimStart([char]0xFEFF)

        # Try by Name (cn attribute) first – works regardless of OU placement
        $computer = Get-ADComputer -Filter "Name -eq '$cleanName'" -Properties DistinguishedName -ErrorAction Stop

        # Fallback: search by SamAccountName (stored as COMPUTERNAME$ in AD)
        if (-not $computer) {
            $sam = "${cleanName}$"
            $computer = Get-ADComputer -Filter "SamAccountName -eq '$sam'" -Properties DistinguishedName -ErrorAction Stop
        }

        if ($computer -and @($computer).Count -gt 0) {
            return @($computer)[0]
        }
        return $null
    } catch {
        # Propagate real errors (permissions, connectivity, etc.) so the
        # caller can surface them as "Error" rather than silent "Not found".
        throw
    }
}

function Remove-ADComputerObject {
    <#
    .SYNOPSIS
        Deletes a computer account from local Active Directory.

    .PARAMETER Name
        The sAMAccountName / computer name (without trailing $).

    .OUTPUTS
        $true if deleted successfully.
        Throws if the deletion fails for a reason other than "not found".

    .NOTES
        Requires the calling account to have permission to delete computer
        objects in the target AD domain (typically Domain Admins or delegated
        rights on the OU).
    #>
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Test-ADModuleAvailable)) {
        throw "ActiveDirectory module (RSAT) is not installed on this machine."
    }

    Import-Module ActiveDirectory -ErrorAction Stop
    $computer = Get-ADComputer -Filter "Name -eq '$Name'" -ErrorAction Stop
    if (-not $computer) {
        throw "Computer '$Name' not found in Active Directory."
    }
    Remove-ADObject -Identity $computer.DistinguishedName -Recursive -Confirm:$false -ErrorAction Stop
    return $true
}
