#Requires -Version 5.1
<#
.SYNOPSIS
    CSV import helper for the Bulk Device Delete Tool.

.DESCRIPTION
    Provides functions to read a CSV file and extract a list of computer names.

    Accepted CSV column names (first match wins, case-insensitive):
      ComputerName, Name, DeviceName, Computer, Hostname, Host

    If none of those headers are present the first column is used.
    Blank lines and duplicate names are automatically removed.
#>

# Column names accepted as the computer-name column (checked in order)
$Script:AcceptedHeaders = @(
    'ComputerName', 'Name', 'DeviceName', 'Computer', 'Hostname', 'Host'
)

function Import-DeviceList {
    <#
    .SYNOPSIS
        Reads a CSV file and returns a deduplicated, sorted array of computer names.

    .PARAMETER Path
        Full path to the CSV file.

    .OUTPUTS
        [string[]] Array of computer names (trimmed, non-empty, unique).

    .EXAMPLE
        $names = Import-DeviceList -Path 'C:\Temp\devices.csv'
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "CSV file not found: $Path"
    }

    $rows = Import-Csv -Path $Path -ErrorAction Stop

    if (-not $rows -or $rows.Count -eq 0) {
        return @()
    }

    # Determine which property to use as the computer name
    $headers    = $rows[0].PSObject.Properties.Name
    $nameColumn = $null

    foreach ($candidate in $Script:AcceptedHeaders) {
        $match = $headers | Where-Object { $_ -ieq $candidate } | Select-Object -First 1
        if ($match) {
            $nameColumn = $match
            break
        }
    }

    # Fall back to the first column if no recognised header found
    if (-not $nameColumn) {
        $nameColumn = $headers[0]
        Write-Verbose "No standard column header found; using first column '$nameColumn' as computer name."
    }

    $names = $rows |
        Select-Object -ExpandProperty $nameColumn |
        ForEach-Object { if ($_ -ne $null) { $_.Trim() } } |
        Where-Object   { $_ -ne '' } |
        Sort-Object    -Unique

    return @($names)
}
