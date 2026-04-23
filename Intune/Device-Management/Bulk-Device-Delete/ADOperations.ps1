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
        $computer = Get-ADComputer -Identity $Name -ErrorAction Stop
        return $computer
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # Computer not found in AD – not an error, just absent
        return $null
    } catch {
        Write-Verbose "Find-ADComputerObject failed for '$Name': $_"
        return $null
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
    Remove-ADComputer -Identity $Name -Confirm:$false -ErrorAction Stop
    return $true
}
