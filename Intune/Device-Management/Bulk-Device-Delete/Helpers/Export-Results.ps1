#Requires -Version 5.1
<#
.SYNOPSIS
    Export helper for the Bulk Device Delete Tool.

.DESCRIPTION
    Provides a function to save the deletion result log to a CSV file.
    The exported CSV contains one row per device per target (AD / Entra / Intune)
    with a status and optional message.
#>

function Export-DeleteResults {
    <#
    .SYNOPSIS
        Writes deletion results to a CSV file chosen by the user via a SaveFileDialog.

    .PARAMETER Results
        Array of PSCustomObjects. Each object should have the properties:
          ComputerName  – device name
          Target        – 'AD', 'EntraID', or 'Intune'
          Status        – 'Deleted', 'NotFound', 'Skipped', or 'Error'
          Message       – optional detail / error text
          Timestamp     – date/time of the action

    .PARAMETER DefaultFileName
        Suggested file name pre-filled in the dialog.

    .OUTPUTS
        The path of the saved file, or $null if the user cancelled.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [string]$DefaultFileName = "BulkDeleteResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    )

    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title            = 'Save Deletion Results'
    $dlg.Filter           = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    $dlg.FileName         = $DefaultFileName
    $dlg.InitialDirectory = [Environment]::GetFolderPath('Desktop')

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    $path = $dlg.FileName
    $Results | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 -Force
    return $path
}
