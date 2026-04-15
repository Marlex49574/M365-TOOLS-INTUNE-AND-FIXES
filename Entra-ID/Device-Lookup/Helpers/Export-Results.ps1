#Requires -Version 5.1
<#
.SYNOPSIS
    Export and clipboard helpers for the Entra ID Device Info Lookup Tool.

.DESCRIPTION
    Provides functions to save the current result set as a CSV file and to copy
    the visible grid content to the Windows clipboard as tab-separated text.
    An optional Excel export (Phase 2) is stubbed out and activates automatically
    when the ImportExcel module is available.
#>

function Export-ResultsToCsv {
    <#
    .SYNOPSIS
        Saves DataGridView rows to a CSV file chosen via a SaveFileDialog.

    .PARAMETER Grid
        The System.Windows.Forms.DataGridView that holds the results.

    .PARAMETER OwnerForm
        The parent WinForms form (used as the dialog owner).

    .OUTPUTS
        Returns the path of the saved file, or $null if the user cancelled.
    #>
    param(
        [Parameter(Mandatory)][System.Windows.Forms.DataGridView]$Grid,
        [System.Windows.Forms.Form]$OwnerForm = $null
    )

    if ($Grid.Rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'No results to export.',
            'Export CSV',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return $null
    }

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title      = 'Export Results to CSV'
    $dlg.Filter     = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    $dlg.DefaultExt = 'csv'
    $dlg.FileName   = "EntraDeviceLookup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

    $result = if ($OwnerForm) { $dlg.ShowDialog($OwnerForm) } else { $dlg.ShowDialog() }

    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

    $filePath = $dlg.FileName

    try {
        # Collect visible (non-hidden) column headers
        $visibleCols = $Grid.Columns |
            Where-Object { $_.Visible } |
            Sort-Object DisplayIndex

        $headers = $visibleCols | ForEach-Object { "`"$($_.HeaderText)`"" }
        $lines   = @("$($headers -join ',')")

        foreach ($row in $Grid.Rows) {
            if ($row.IsNewRow) { continue }
            $cells = foreach ($col in $visibleCols) {
                $val = $row.Cells[$col.Index].Value
                # Escape double-quotes inside cell values
                "`"$(([string]$val) -replace '"','""')`""
            }
            $lines += $cells -join ','
        }

        $lines | Set-Content -Path $filePath -Encoding UTF8
        return $filePath
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to save CSV:`n$_",
            'Export Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $null
    }
}

function Export-ResultsToExcel {
    <#
    .SYNOPSIS
        Saves DataGridView rows to a formatted Excel file using the ImportExcel module.
        If ImportExcel is not installed, falls back to Export-ResultsToCsv.

    .PARAMETER Grid
        The System.Windows.Forms.DataGridView that holds the results.

    .PARAMETER OwnerForm
        The parent WinForms form (used as the dialog owner).

    .OUTPUTS
        Returns the path of the saved file, or $null if the user cancelled.
    #>
    param(
        [Parameter(Mandatory)][System.Windows.Forms.DataGridView]$Grid,
        [System.Windows.Forms.Form]$OwnerForm = $null
    )

    if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
        $ans = [System.Windows.Forms.MessageBox]::Show(
            "The 'ImportExcel' module is not installed.`nFall back to CSV export?",
            'ImportExcel Not Found',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            return Export-ResultsToCsv -Grid $Grid -OwnerForm $OwnerForm
        }
        return $null
    }

    if ($Grid.Rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'No results to export.',
            'Export Excel',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return $null
    }

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title      = 'Export Results to Excel'
    $dlg.Filter     = 'Excel files (*.xlsx)|*.xlsx|All files (*.*)|*.*'
    $dlg.DefaultExt = 'xlsx'
    $dlg.FileName   = "EntraDeviceLookup_$(Get-Date -Format 'yyyyMMdd_HHmmss').xlsx"

    $result = if ($OwnerForm) { $dlg.ShowDialog($OwnerForm) } else { $dlg.ShowDialog() }
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

    $filePath = $dlg.FileName

    try {
        $visibleCols = $Grid.Columns |
            Where-Object { $_.Visible } |
            Sort-Object DisplayIndex

        $data = foreach ($row in $Grid.Rows) {
            if ($row.IsNewRow) { continue }
            $obj = [ordered]@{}
            foreach ($col in $visibleCols) {
                $obj[$col.HeaderText] = $row.Cells[$col.Index].Value
            }
            [PSCustomObject]$obj
        }

        $data | Export-Excel -Path $filePath -AutoSize -BoldTopRow -FreezeTopRow -WorksheetName 'Devices'
        return $filePath
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to save Excel file:`n$_",
            'Export Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $null
    }
}

function Copy-GridToClipboard {
    <#
    .SYNOPSIS
        Copies the visible DataGridView content (headers + rows) to the Windows
        clipboard as tab-separated text, ready to paste into Excel, Notepad, etc.

    .PARAMETER Grid
        The System.Windows.Forms.DataGridView that holds the results.

    .OUTPUTS
        Returns $true on success, $false on failure.
    #>
    param(
        [Parameter(Mandatory)][System.Windows.Forms.DataGridView]$Grid
    )

    if ($Grid.Rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'No results to copy.',
            'Copy to Clipboard',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return $false
    }

    try {
        $visibleCols = $Grid.Columns |
            Where-Object { $_.Visible } |
            Sort-Object DisplayIndex

        $sb = New-Object System.Text.StringBuilder

        # Header row
        $sb.AppendLine(($visibleCols | ForEach-Object { $_.HeaderText }) -join "`t") | Out-Null

        foreach ($row in $Grid.Rows) {
            if ($row.IsNewRow) { continue }
            $cells = foreach ($col in $visibleCols) {
                [string]$row.Cells[$col.Index].Value
            }
            $sb.AppendLine($cells -join "`t") | Out-Null
        }

        [System.Windows.Forms.Clipboard]::SetText($sb.ToString())
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to copy to clipboard:`n$_",
            'Clipboard Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }
}
