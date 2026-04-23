#Requires -Version 5.1
<#
.SYNOPSIS
    Builds and displays the main WinForms window for the Bulk Device Delete Tool.

.DESCRIPTION
    Constructs all UI controls:
      - CSV file browse / import panel
      - Device list DataGridView with per-row status columns
      - Target checkboxes (Local AD / Entra ID / Intune)
      - Preview, Delete and Export buttons
      - Scrollable log / output panel
      - Dark / Light theme toggle

    This file is dot-sourced by Remove-DeviceBulkTool.ps1, which must have
    already loaded Theme.ps1, GraphOperations.ps1, ADOperations.ps1,
    Helpers/Import-DeviceList.ps1, and Helpers/Export-Results.ps1.

.NOTES
    Graph authentication must be established before this window is opened.
    Use Connect-BulkDeleteTool (Auth.ps1) or Connect-MgGraph prior to calling
    Show-BulkDeleteForm.
#>

function Show-BulkDeleteForm {
    <#
    .SYNOPSIS
        Constructs and opens the Bulk Device Delete application window (blocking).
    #>

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # ─── In-scope state ───────────────────────────────────────────────────────
    $script:DeviceNames  = @()           # names imported from CSV
    $script:ResultLog    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $script:AppTitle     = 'Bulk Device Delete Tool'

    # ─── Form ─────────────────────────────────────────────────────────────────
    $form = New-Object System.Windows.Forms.Form
    $form.Text          = $script:AppTitle
    $form.Size          = New-Object System.Drawing.Size(1100, 780)
    $form.MinimumSize   = New-Object System.Drawing.Size(860, 620)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.Font          = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.KeyPreview    = $true

    # ─── Top panel – CSV browse ───────────────────────────────────────────────
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock   = [System.Windows.Forms.DockStyle]::Top
    $topPanel.Height = 115
    $topPanel.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 4)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text     = "🗑️  $script:AppTitle"
    $lblTitle.Font     = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(12, 10)

    $lblFile = New-Object System.Windows.Forms.Label
    $lblFile.Text     = 'CSV File:'
    $lblFile.AutoSize = $true
    $lblFile.Location = New-Object System.Drawing.Point(12, 52)

    $txtCsvPath = New-Object System.Windows.Forms.TextBox
    $txtCsvPath.Width    = 640
    $txtCsvPath.Height   = 26
    $txtCsvPath.Location = New-Object System.Drawing.Point(75, 49)
    $txtCsvPath.ReadOnly = $true
    $txtCsvPath.PlaceholderText = 'Select a CSV file containing computer names…'

    $btnBrowse = New-StyledButton -Text '📂 Browse…' -Width 110 -Height 26
    $btnBrowse.Location = New-Object System.Drawing.Point(725, 49)

    $btnLoadCsv = New-StyledButton -Text '📋 Load List' -Width 110 -Height 26
    $btnLoadCsv.Location = New-Object System.Drawing.Point(845, 49)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text      = 'No file loaded.'
    $lblInfo.AutoSize  = $true
    $lblInfo.Location  = New-Object System.Drawing.Point(12, 82)
    $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 170)

    $btnTheme = New-SecondaryButton -Text '☀️ Light Mode' -Width 120 -Height 26
    $btnTheme.Location = New-Object System.Drawing.Point(845, 82)

    $topPanel.Controls.AddRange(@(
        $lblTitle, $lblFile, $txtCsvPath,
        $btnBrowse, $btnLoadCsv, $lblInfo, $btnTheme
    ))

    # ─── Options panel – target checkboxes ───────────────────────────────────
    $optPanel = New-Object System.Windows.Forms.Panel
    $optPanel.Dock   = [System.Windows.Forms.DockStyle]::Top
    $optPanel.Height = 42
    $optPanel.Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 0)

    $lblTargets = New-Object System.Windows.Forms.Label
    $lblTargets.Text     = 'Delete from:'
    $lblTargets.AutoSize = $true
    $lblTargets.Location = New-Object System.Drawing.Point(12, 12)

    $chkAD = New-Object System.Windows.Forms.CheckBox
    $chkAD.Text     = 'Local Active Directory'
    $chkAD.Checked  = $true
    $chkAD.AutoSize = $true
    $chkAD.Location = New-Object System.Drawing.Point(110, 10)

    $chkEntra = New-Object System.Windows.Forms.CheckBox
    $chkEntra.Text     = 'Microsoft Entra ID (Azure AD)'
    $chkEntra.Checked  = $true
    $chkEntra.AutoSize = $true
    $chkEntra.Location = New-Object System.Drawing.Point(300, 10)

    $chkIntune = New-Object System.Windows.Forms.CheckBox
    $chkIntune.Text     = 'Microsoft Intune'
    $chkIntune.Checked  = $true
    $chkIntune.AutoSize = $true
    $chkIntune.Location = New-Object System.Drawing.Point(530, 10)

    $optPanel.Controls.AddRange(@($lblTargets, $chkAD, $chkEntra, $chkIntune))

    # ─── Action panel – buttons ───────────────────────────────────────────────
    $actionPanel = New-Object System.Windows.Forms.Panel
    $actionPanel.Dock   = [System.Windows.Forms.DockStyle]::Top
    $actionPanel.Height = 44
    $actionPanel.Padding = New-Object System.Windows.Forms.Padding(12, 6, 12, 0)

    $btnPreview = New-StyledButton -Text '🔍 Preview' -Width 120 -Height 30
    $btnPreview.Location = New-Object System.Drawing.Point(12, 6)
    $btnPreview.Enabled  = $false

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text      = '🗑️  Delete All'
    $btnDelete.Width     = 140
    $btnDelete.Height    = 30
    $btnDelete.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDelete.FlatAppearance.BorderSize = 0
    $btnDelete.BackColor = [System.Drawing.Color]::FromArgb(196, 43, 28)
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.Font      = New-Object System.Drawing.Font('Segoe UI', 9)
    $btnDelete.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btnDelete.Tag       = 'accent'
    $btnDelete.Location  = New-Object System.Drawing.Point(144, 6)
    $btnDelete.Enabled   = $false

    $btnExport = New-SecondaryButton -Text '💾 Export Log' -Width 120 -Height 30
    $btnExport.Location = New-Object System.Drawing.Point(296, 6)
    $btnExport.Enabled  = $false

    $btnClear = New-SecondaryButton -Text '✖ Clear' -Width 90 -Height 30
    $btnClear.Location = New-Object System.Drawing.Point(428, 6)

    $actionPanel.Controls.AddRange(@($btnPreview, $btnDelete, $btnExport, $btnClear))

    # ─── Status strip ─────────────────────────────────────────────────────────
    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text  = 'Ready. Load a CSV file to begin.'
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $statusStrip.Items.Add($statusLabel) | Out-Null

    # ─── Split container – grid (top) / log (bottom) ─────────────────────────
    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $split.Orientation = [System.Windows.Forms.Orientation]::Horizontal
    $split.SplitterDistance = 380
    $split.Panel1MinSize    = 120
    $split.Panel2MinSize    = 80

    # ─── DataGridView – device list ───────────────────────────────────────────
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock                   = [System.Windows.Forms.DockStyle]::Fill
    $grid.AllowUserToAddRows     = $false
    $grid.AllowUserToDeleteRows  = $false
    $grid.ReadOnly               = $true
    $grid.SelectionMode          = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.MultiSelect            = $true
    $grid.RowHeadersVisible      = $false
    $grid.AutoSizeColumnsMode    = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.ColumnHeadersHeight    = 28

    # Define columns
    $colName   = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.Name       = 'ComputerName'
    $colName.HeaderText = 'Computer Name'
    $colName.FillWeight = 25

    $colAD     = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAD.Name       = 'ADStatus'
    $colAD.HeaderText = 'Local AD'
    $colAD.FillWeight = 25

    $colEntra  = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colEntra.Name       = 'EntraStatus'
    $colEntra.HeaderText = 'Entra ID'
    $colEntra.FillWeight = 25

    $colIntune = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colIntune.Name       = 'IntuneStatus'
    $colIntune.HeaderText = 'Intune'
    $colIntune.FillWeight = 25

    $grid.Columns.AddRange($colName, $colAD, $colEntra, $colIntune)

    $split.Panel1.Controls.Add($grid)

    # ─── Log RichTextBox ──────────────────────────────────────────────────────
    $logBox = New-Object System.Windows.Forms.RichTextBox
    $logBox.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $logBox.ReadOnly  = $true
    $logBox.Font      = New-Object System.Drawing.Font('Consolas', 8.5)
    $logBox.WordWrap  = $false
    $logBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both

    $split.Panel2.Controls.Add($logBox)

    # ─── Assemble form ────────────────────────────────────────────────────────
    $form.Controls.AddRange(@($statusStrip, $split, $actionPanel, $optPanel, $topPanel))

    # ─── Helper: append coloured log line ─────────────────────────────────────
    $appendLog = {
        param([string]$Message, [string]$Level = 'Info')
        $ts = Get-Date -Format 'HH:mm:ss'
        $prefix = "[$ts] "

        $logBox.SelectionStart  = $logBox.TextLength
        $logBox.SelectionLength = 0

        switch ($Level) {
            'Success' { $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(0, 200, 100) }
            'Error'   { $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(220, 80, 60)  }
            'Warning' { $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(210, 160, 40) }
            default   { $logBox.SelectionColor = (Get-ThemeColor 'Text') }
        }

        $logBox.AppendText("$prefix$Message`n")
        $logBox.ScrollToCaret()
    }

    # ─── Helper: update grid row status ───────────────────────────────────────
    $setRowStatus = {
        param([int]$RowIndex, [string]$Column, [string]$Status)
        if ($RowIndex -ge 0 -and $RowIndex -lt $grid.Rows.Count) {
            $cell = $grid.Rows[$RowIndex].Cells[$Column]
            $cell.Value = $Status
            switch -Wildcard ($Status) {
                'Deleted'  { $cell.Style.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 100) }
                'NotFound' { $cell.Style.ForeColor = [System.Drawing.Color]::FromArgb(210, 160, 40) }
                'Skipped'  { $cell.Style.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 170) }
                'Error*'   { $cell.Style.ForeColor = [System.Drawing.Color]::FromArgb(220, 80, 60)  }
                default    { $cell.Style.ForeColor = (Get-ThemeColor 'Text') }
            }
        }
    }

    # ─── Helper: add result to log list ───────────────────────────────────────
    $addResult = {
        param([string]$Name, [string]$Target, [string]$Status, [string]$Message = '')
        $script:ResultLog.Add([PSCustomObject]@{
            ComputerName = $Name
            Target       = $Target
            Status       = $Status
            Message      = $Message
            Timestamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        })
    }

    # ─── Event: Browse CSV ────────────────────────────────────────────────────
    $btnBrowse.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title  = 'Select CSV file with computer names'
        $dlg.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtCsvPath.Text = $dlg.FileName
        }
    })

    # ─── Event: Load CSV ──────────────────────────────────────────────────────
    $btnLoadCsv.Add_Click({
        $path = $txtCsvPath.Text.Trim()
        if ([string]::IsNullOrEmpty($path)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Please select a CSV file first.',
                'No File Selected',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        try {
            $script:DeviceNames = Import-DeviceList -Path $path
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to read CSV file:`n`n$_",
                'CSV Import Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }

        if ($script:DeviceNames.Count -eq 0) {
            $lblInfo.Text = 'No computer names found in file.'
            $statusLabel.Text = 'CSV loaded – no entries found.'
            return
        }

        # Populate grid
        $grid.Rows.Clear()
        $script:ResultLog.Clear()

        foreach ($n in $script:DeviceNames) {
            $grid.Rows.Add($n, '—', '—', '—') | Out-Null
        }

        $count = $script:DeviceNames.Count
        $lblInfo.Text     = "Loaded $count computer name(s) from: $(Split-Path $path -Leaf)"
        $statusLabel.Text = "$count device(s) ready for processing."
        $btnPreview.Enabled = $true
        $btnDelete.Enabled  = $true

        & $appendLog "Loaded $count device name(s) from $path" 'Info'
    })

    # ─── Event: Preview ───────────────────────────────────────────────────────
    $btnPreview.Add_Click({
        if ($script:DeviceNames.Count -eq 0) { return }

        $btnPreview.Enabled = $false
        $btnDelete.Enabled  = $false
        $statusLabel.Text   = 'Previewing – querying AD, Entra ID and Intune…'
        [System.Windows.Forms.Application]::DoEvents()

        & $appendLog '── Preview started ──────────────────────────────' 'Info'

        for ($i = 0; $i -lt $script:DeviceNames.Count; $i++) {
            $name = $script:DeviceNames[$i]

            # AD
            if ($chkAD.Checked) {
                if (Test-ADModuleAvailable) {
                    $adObj = Find-ADComputerObject -Name $name
                    if ($adObj) {
                        & $setRowStatus $i 'ADStatus' 'Found'
                        & $appendLog "  $name  [AD] Found: $($adObj.DistinguishedName)" 'Info'
                    } else {
                        & $setRowStatus $i 'ADStatus' 'NotFound'
                        & $appendLog "  $name  [AD] Not found." 'Warning'
                    }
                } else {
                    & $setRowStatus $i 'ADStatus' 'Skipped (no RSAT)'
                    & $appendLog "  $name  [AD] Skipped – ActiveDirectory module not available." 'Warning'
                }
            } else {
                & $setRowStatus $i 'ADStatus' 'Skipped'
            }

            # Entra ID
            if ($chkEntra.Checked) {
                try {
                    $entraObjs = Find-EntraDevice -Name $name
                    if ($entraObjs -and $entraObjs.Count -gt 0) {
                        & $setRowStatus $i 'EntraStatus' "Found ($($entraObjs.Count))"
                        & $appendLog "  $name  [Entra] Found $($entraObjs.Count) object(s)." 'Info'
                    } else {
                        & $setRowStatus $i 'EntraStatus' 'NotFound'
                        & $appendLog "  $name  [Entra] Not found." 'Warning'
                    }
                } catch {
                    & $setRowStatus $i 'EntraStatus' 'Error'
                    & $appendLog "  $name  [Entra] Error during preview: $_" 'Error'
                }
            } else {
                & $setRowStatus $i 'EntraStatus' 'Skipped'
            }

            # Intune
            if ($chkIntune.Checked) {
                try {
                    $intuneObjs = Find-IntuneDevice -Name $name
                    if ($intuneObjs -and $intuneObjs.Count -gt 0) {
                        & $setRowStatus $i 'IntuneStatus' "Found ($($intuneObjs.Count))"
                        & $appendLog "  $name  [Intune] Found $($intuneObjs.Count) record(s)." 'Info'
                    } else {
                        & $setRowStatus $i 'IntuneStatus' 'NotFound'
                        & $appendLog "  $name  [Intune] Not found." 'Warning'
                    }
                } catch {
                    & $setRowStatus $i 'IntuneStatus' 'Error'
                    & $appendLog "  $name  [Intune] Error during preview: $_" 'Error'
                }
            } else {
                & $setRowStatus $i 'IntuneStatus' 'Skipped'
            }

            [System.Windows.Forms.Application]::DoEvents()
        }

        & $appendLog '── Preview complete ─────────────────────────────' 'Info'
        $statusLabel.Text   = 'Preview complete. Review the list and click Delete All to proceed.'
        $btnPreview.Enabled = $true
        $btnDelete.Enabled  = $true
    })

    # ─── Event: Delete All ────────────────────────────────────────────────────
    $btnDelete.Add_Click({
        if ($script:DeviceNames.Count -eq 0) { return }

        if (-not $chkAD.Checked -and -not $chkEntra.Checked -and -not $chkIntune.Checked) {
            [System.Windows.Forms.MessageBox]::Show(
                'Please select at least one deletion target (AD / Entra ID / Intune).',
                'No Target Selected',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        $targets = @()
        if ($chkAD.Checked)     { $targets += 'Local AD' }
        if ($chkEntra.Checked)  { $targets += 'Entra ID' }
        if ($chkIntune.Checked) { $targets += 'Intune' }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "⚠️  You are about to DELETE $($script:DeviceNames.Count) device(s) from:`n`n" +
            "  • $($targets -join "`n  • ")`n`n" +
            "This action is IRREVERSIBLE.`n`nAre you sure you want to continue?",
            'Confirm Deletion',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2)

        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        $btnPreview.Enabled = $false
        $btnDelete.Enabled  = $false
        $script:ResultLog.Clear()

        & $appendLog '── Deletion started ─────────────────────────────' 'Info'
        $deletionCount = 0; $errors = 0

        for ($i = 0; $i -lt $script:DeviceNames.Count; $i++) {
            $name = $script:DeviceNames[$i]
            & $appendLog "Processing: $name" 'Info'

            # ── Local AD ────────────────────────────────────────────────────
            if ($chkAD.Checked) {
                if (Test-ADModuleAvailable) {
                    try {
                        $adObj = Find-ADComputerObject -Name $name
                        if ($adObj) {
                            Remove-ADComputerObject -Name $name
                            & $setRowStatus $i 'ADStatus' 'Deleted'
                            & $appendLog "  $name  [AD] Deleted successfully." 'Success'
                            & $addResult $name 'AD' 'Deleted'
                            $deletionCount++
                        } else {
                            & $setRowStatus $i 'ADStatus' 'NotFound'
                            & $appendLog "  $name  [AD] Not found – skipped." 'Warning'
                            & $addResult $name 'AD' 'NotFound'
                        }
                    } catch {
                        & $setRowStatus $i 'ADStatus' "Error"
                        & $appendLog "  $name  [AD] Error: $_" 'Error'
                        & $addResult $name 'AD' 'Error' "$_"
                        $errors++
                    }
                } else {
                    & $setRowStatus $i 'ADStatus' 'Skipped (no RSAT)'
                    & $appendLog "  $name  [AD] Skipped – ActiveDirectory module not available." 'Warning'
                    & $addResult $name 'AD' 'Skipped' 'RSAT ActiveDirectory module not installed'
                }
            } else {
                & $setRowStatus $i 'ADStatus' 'Skipped'
            }

            # ── Entra ID ────────────────────────────────────────────────────
            if ($chkEntra.Checked) {
                try {
                    $entraObjs = Find-EntraDevice -Name $name
                    if ($entraObjs -and $entraObjs.Count -gt 0) {
                        foreach ($obj in $entraObjs) {
                            Remove-EntraDevice -ObjectId $obj.id
                        }
                        & $setRowStatus $i 'EntraStatus' 'Deleted'
                        & $appendLog "  $name  [Entra] Deleted $($entraObjs.Count) object(s)." 'Success'
                        & $addResult $name 'EntraID' 'Deleted' "Removed $($entraObjs.Count) object(s)"
                        $deletionCount++
                    } else {
                        & $setRowStatus $i 'EntraStatus' 'NotFound'
                        & $appendLog "  $name  [Entra] Not found – skipped." 'Warning'
                        & $addResult $name 'EntraID' 'NotFound'
                    }
                } catch {
                    & $setRowStatus $i 'EntraStatus' 'Error'
                    & $appendLog "  $name  [Entra] Error: $_" 'Error'
                    & $addResult $name 'EntraID' 'Error' "$_"
                    $errors++
                }
            } else {
                & $setRowStatus $i 'EntraStatus' 'Skipped'
            }

            # ── Intune ──────────────────────────────────────────────────────
            if ($chkIntune.Checked) {
                try {
                    $intuneObjs = Find-IntuneDevice -Name $name
                    if ($intuneObjs -and $intuneObjs.Count -gt 0) {
                        foreach ($obj in $intuneObjs) {
                            Remove-IntuneDevice -ManagedDeviceId $obj.id
                        }
                        & $setRowStatus $i 'IntuneStatus' 'Deleted'
                        & $appendLog "  $name  [Intune] Deleted $($intuneObjs.Count) record(s)." 'Success'
                        & $addResult $name 'Intune' 'Deleted' "Removed $($intuneObjs.Count) record(s)"
                        $deletionCount++
                    } else {
                        & $setRowStatus $i 'IntuneStatus' 'NotFound'
                        & $appendLog "  $name  [Intune] Not found – skipped." 'Warning'
                        & $addResult $name 'Intune' 'NotFound'
                    }
                } catch {
                    & $setRowStatus $i 'IntuneStatus' 'Error'
                    & $appendLog "  $name  [Intune] Error: $_" 'Error'
                    & $addResult $name 'Intune' 'Error' "$_"
                    $errors++
                }
            } else {
                & $setRowStatus $i 'IntuneStatus' 'Skipped'
            }

            [System.Windows.Forms.Application]::DoEvents()
        }

        & $appendLog "── Deletion complete – $deletionCount deletion(s) performed, $errors error(s) ──" 'Info'
        $statusLabel.Text   = "Done. $deletionCount deletion(s) performed, $errors error(s). Use 'Export Log' to save results."
        $btnPreview.Enabled = $true
        $btnDelete.Enabled  = $true
        $btnExport.Enabled  = ($script:ResultLog.Count -gt 0)
    })

    # ─── Event: Export Log ────────────────────────────────────────────────────
    $btnExport.Add_Click({
        if ($script:ResultLog.Count -eq 0) { return }
        try {
            $saved = Export-DeleteResults -Results $script:ResultLog.ToArray()
            if ($saved) {
                & $appendLog "Log exported to: $saved" 'Success'
                $statusLabel.Text = "Log saved to $saved"
            }
        } catch {
            & $appendLog "Export failed: $_" 'Error'
        }
    })

    # ─── Event: Clear ─────────────────────────────────────────────────────────
    $btnClear.Add_Click({
        $grid.Rows.Clear()
        $logBox.Clear()
        $script:DeviceNames  = @()
        $script:ResultLog.Clear()
        $txtCsvPath.Text      = ''
        $lblInfo.Text         = 'No file loaded.'
        $statusLabel.Text     = 'Cleared. Load a CSV file to begin.'
        $btnPreview.Enabled   = $false
        $btnDelete.Enabled    = $false
        $btnExport.Enabled    = $false
    })

    # ─── Event: Theme toggle ──────────────────────────────────────────────────
    $btnTheme.Add_Click({
        $newTheme = Toggle-Theme
        $btnTheme.Text = if ($newTheme -eq 'Dark') { '☀️ Light Mode' } else { '🌙 Dark Mode' }
        Apply-ThemeToForm -Control $form
    })

    # ─── Event: Enter key triggers Load in CSV box ────────────────────────────
    $form.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $form.Close()
        }
    })

    # ─── Apply initial theme ──────────────────────────────────────────────────
    Apply-ThemeToForm -Control $form

    # ─── Show form ────────────────────────────────────────────────────────────
    [System.Windows.Forms.Application]::Run($form)
}
