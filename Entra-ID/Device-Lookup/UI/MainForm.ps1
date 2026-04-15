#Requires -Version 5.1
<#
.SYNOPSIS
    Builds and displays the main WinForms window for the Entra ID Device Info Lookup Tool.

.DESCRIPTION
    Constructs all UI controls (search panel, result DataGridView, detail side panel,
    status bar, export buttons) and wires up event handlers.

    This file is dot-sourced by Get-EntraDeviceInfoTool.ps1, which must have already
    loaded Theme.ps1, DetailPanel.ps1, GraphQueries.ps1,
    Helpers/Format-DeviceRow.ps1, and Helpers/Export-Results.ps1.

.NOTES
    Graph authentication must be established before this window is opened.
    Use Connect-MgGraph (or your organisation's Auth.ps1) prior to calling
    Show-MainForm.
#>

function Show-MainForm {
    <#
    .SYNOPSIS
        Constructs and opens the main application window (blocking until closed).
    #>

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # -------------------------------------------------------------------------
    # Window
    # -------------------------------------------------------------------------
    $script:AppTitle = 'Entra ID – Device Info Lookup'
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = $script:AppTitle
    $form.Size            = New-Object System.Drawing.Size(1200, 720)
    $form.MinimumSize     = New-Object System.Drawing.Size(900, 580)
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.KeyPreview      = $true

    # Try to set the window icon to the Microsoft blue circle if available
    try {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon(
            "$env:SystemRoot\System32\imageres.dll")
        $form.Icon = $icon
    } catch { }

    # -------------------------------------------------------------------------
    # Top search panel
    # -------------------------------------------------------------------------
    $searchPanel = New-Object System.Windows.Forms.Panel
    $searchPanel.Dock    = [System.Windows.Forms.DockStyle]::Top
    $searchPanel.Height  = 100
    $searchPanel.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)

    # Title label
    $lblAppTitle = New-Object System.Windows.Forms.Label
    $lblAppTitle.Text     = "🔵  $script:AppTitle"
    $lblAppTitle.Font     = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
    $lblAppTitle.AutoSize = $true
    $lblAppTitle.Location = New-Object System.Drawing.Point(12, 10)

    # Mode radio buttons
    $rbNames = New-Object System.Windows.Forms.RadioButton
    $rbNames.Text     = 'Computer Name(s)'
    $rbNames.Checked  = $true
    $rbNames.AutoSize = $true
    $rbNames.Location = New-Object System.Drawing.Point(12, 48)

    $rbOU = New-Object System.Windows.Forms.RadioButton
    $rbOU.Text     = 'OU Path (Hybrid AD)'
    $rbOU.AutoSize = $true
    $rbOU.Location = New-Object System.Drawing.Point(165, 48)

    $rbGroup = New-Object System.Windows.Forms.RadioButton
    $rbGroup.Text     = 'Entra Group Name'
    $rbGroup.AutoSize = $true
    $rbGroup.Location = New-Object System.Drawing.Point(325, 48)

    # Search input box
    $txtInput = New-Object System.Windows.Forms.TextBox
    $txtInput.Width      = 600
    $txtInput.Height     = 28
    $txtInput.Font       = New-Object System.Drawing.Font('Segoe UI', 9)
    $txtInput.Location   = New-Object System.Drawing.Point(12, 70)
    $txtInput.PlaceholderText = 'Enter comma-separated names, or one name per line…'

    # Search button
    $btnSearch = New-StyledButton -Text '🔍 Search' -Width 110 -Height 28
    $btnSearch.Location = New-Object System.Drawing.Point(620, 70)

    # Theme toggle button
    $btnTheme = New-SecondaryButton -Text '☀️ Light Mode' -Width 120 -Height 28
    $btnTheme.Location = New-Object System.Drawing.Point(740, 70)

    $searchPanel.Controls.AddRange(@(
        $lblAppTitle, $rbNames, $rbOU, $rbGroup,
        $txtInput, $btnSearch, $btnTheme
    ))

    # -------------------------------------------------------------------------
    # Status bar
    # -------------------------------------------------------------------------
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusBar.Dock = [System.Windows.Forms.DockStyle]::Bottom

    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text  = 'Ready'
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    $progressBar = New-Object System.Windows.Forms.ToolStripProgressBar
    $progressBar.Width   = 160
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value   = 0
    $progressBar.Visible = $false

    $lblResultCount = New-Object System.Windows.Forms.ToolStripStatusLabel
    $lblResultCount.Text = '0 devices'

    $statusBar.Items.AddRange(@($statusLabel, $progressBar, $lblResultCount))

    # -------------------------------------------------------------------------
    # Export / action toolbar (bottom, above status bar)
    # -------------------------------------------------------------------------
    $toolPanel = New-Object System.Windows.Forms.Panel
    $toolPanel.Dock   = [System.Windows.Forms.DockStyle]::Bottom
    $toolPanel.Height = 44
    $toolPanel.Padding = New-Object System.Windows.Forms.Padding(12, 6, 12, 6)

    $btnExportCsv = New-SecondaryButton -Text '💾 Export CSV' -Width 110 -Height 30
    $btnExportCsv.Location = New-Object System.Drawing.Point(12, 7)

    $btnExportExcel = New-SecondaryButton -Text '📊 Export Excel' -Width 120 -Height 30
    $btnExportExcel.Location = New-Object System.Drawing.Point(130, 7)

    $btnCopyTable = New-SecondaryButton -Text '📋 Copy Table' -Width 110 -Height 30
    $btnCopyTable.Location = New-Object System.Drawing.Point(258, 7)

    $btnClear = New-SecondaryButton -Text '🗑 Clear' -Width 80 -Height 30
    $btnClear.Location = New-Object System.Drawing.Point(376, 7)

    # Quick filter box (client-side)
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text     = 'Filter:'
    $lblFilter.AutoSize = $true
    $lblFilter.Location = New-Object System.Drawing.Point(480, 13)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Width    = 200
    $txtFilter.Location = New-Object System.Drawing.Point(520, 9)
    $txtFilter.PlaceholderText = 'Type to filter…'

    $toolPanel.Controls.AddRange(@(
        $btnExportCsv, $btnExportExcel, $btnCopyTable, $btnClear, $lblFilter, $txtFilter
    ))

    # -------------------------------------------------------------------------
    # Main content area: DataGridView + detail side panel
    # -------------------------------------------------------------------------
    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $splitContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $splitContainer.SplitterDistance = 820
    $splitContainer.Panel2MinSize    = 0
    $splitContainer.IsSplitterFixed  = $false

    # DataGridView
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock                         = [System.Windows.Forms.DockStyle]::Fill
    $grid.AllowUserToAddRows           = $false
    $grid.AllowUserToDeleteRows        = $false
    $grid.ReadOnly                     = $true
    $grid.SelectionMode                = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.MultiSelect                  = $false
    $grid.AutoSizeColumnsMode          = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.ColumnHeadersHeightSizeMode  = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
    $grid.RowHeadersVisible            = $false
    $grid.BorderStyle                  = [System.Windows.Forms.BorderStyle]::None
    $grid.CellBorderStyle             = [System.Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
    $grid.Font                         = New-Object System.Drawing.Font('Segoe UI', 9)

    $splitContainer.Panel1.Controls.Add($grid)

    # Detail panel (right side)
    $detailResult = New-DetailPanel -PanelWidth 340 -GetColor { param($n) Get-ThemeColor $n }
    $detailPanel  = $detailResult.Panel
    $splitContainer.Panel2.Controls.Add($detailPanel)
    $splitContainer.Panel2Collapsed = $true   # hidden until a row is selected

    # -------------------------------------------------------------------------
    # Column definitions (visible columns only; hidden _ columns added later)
    # -------------------------------------------------------------------------
    $visibleColumns = @(
        @{ Name = 'Name';         Header = 'Name';         Width = 160 }
        @{ Name = 'Join Type';    Header = 'Join Type';    Width = 120 }
        @{ Name = 'Owner';        Header = 'Owner';        Width = 160 }
        @{ Name = 'MDM Enrolled'; Header = 'MDM';          Width = 60  }
        @{ Name = 'Compliant';    Header = 'Compliant';    Width = 80  }
        @{ Name = 'OS';           Header = 'OS';           Width = 160 }
        @{ Name = 'Enabled';      Header = 'Enabled';      Width = 60  }
        @{ Name = 'Reg. Date';    Header = 'Reg. Date';    Width = 115 }
        @{ Name = 'Last Active';  Header = 'Last Active';  Width = 115 }
    )

    $hiddenColumns = @(
        '_DeviceId', '_ObjectId', '_TrustType',
        '_isCompliant', '_isManaged', '_accountEnabled',
        '_OwnerUPN', '_OwnerName', '_IntuneState', '_IntuneEncrypt',
        '_OS', '_OSVersion', '_LastActivity', '_IsStale'
    )

    foreach ($col in $visibleColumns) {
        $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $c.Name          = $col.Name
        $c.HeaderText    = $col.Header
        $c.FillWeight    = $col.Width
        $c.SortMode      = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
        $grid.Columns.Add($c) | Out-Null
    }
    foreach ($hc in $hiddenColumns) {
        $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $c.Name    = $hc
        $c.Visible = $false
        $grid.Columns.Add($c) | Out-Null
    }

    # -------------------------------------------------------------------------
    # In-memory result cache (to power client-side filtering)
    # -------------------------------------------------------------------------
    $script:AllRows = [System.Collections.Generic.List[hashtable]]::new()

    # -------------------------------------------------------------------------
    # Helper: populate grid from $script:AllRows, applying the filter string
    # -------------------------------------------------------------------------
    function Update-Grid {
        param([string]$Filter = '')
        $grid.Rows.Clear()
        $filterLower = $Filter.Trim().ToLower()

        foreach ($rowData in $script:AllRows) {
            # Apply client-side filter (checks all visible column values)
            if ($filterLower) {
                $match = $false
                foreach ($col in $visibleColumns) {
                    $val = [string]$rowData[$col.Name]
                    if ($val.ToLower().Contains($filterLower)) { $match = $true; break }
                }
                if (-not $match) { continue }
            }

            $allColNames  = $visibleColumns + ($hiddenColumns | ForEach-Object { @{ Name = $_ } })
            $cellValues   = foreach ($col in $allColNames) { $rowData[$col.Name] }
            $rowIndex = $grid.Rows.Add($cellValues)
            $row      = $grid.Rows[$rowIndex]

            # ── Row colour-coding ──────────────────────────────────────────
            $isDisabled  = $rowData['_accountEnabled'] -eq $false
            $isStale     = $rowData['_IsStale'] -eq $true
            $isCompliant = $rowData['_isCompliant']
            $mdm         = $rowData['_isManaged']

            if ($isDisabled) {
                $row.DefaultCellStyle.BackColor = Get-ThemeColor 'DisabledBg'
                $row.DefaultCellStyle.ForeColor = Get-ThemeColor 'Disabled'
            } elseif ($isStale) {
                $row.DefaultCellStyle.BackColor = Get-ThemeColor 'Stale'
            } elseif ($isCompliant -eq $false -or $mdm -eq $false) {
                $row.DefaultCellStyle.BackColor = Get-ThemeColor 'WarningBg'
            } elseif ($isCompliant -eq $true) {
                $row.DefaultCellStyle.BackColor = Get-ThemeColor 'SuccessBg'
            }
        }

        $lblResultCount.Text = "$($grid.Rows.Count) device$(if ($grid.Rows.Count -ne 1) {'s'})"
    }

    # -------------------------------------------------------------------------
    # Helper: set status text
    # -------------------------------------------------------------------------
    function Set-Status {
        param([string]$Message, [int]$Progress = -1)
        $statusLabel.Text = $Message
        if ($Progress -ge 0) {
            $progressBar.Value   = [Math]::Min($Progress, 100)
            $progressBar.Visible = $true
        } else {
            $progressBar.Visible = $false
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    # -------------------------------------------------------------------------
    # Helper: add a row-data hashtable to the result set
    # -------------------------------------------------------------------------
    function Add-ResultRow {
        param([hashtable]$RowData)
        $script:AllRows.Add($RowData)
    }

    # -------------------------------------------------------------------------
    # SEARCH logic
    # -------------------------------------------------------------------------
    $btnSearch.Add_Click({
        $input = $txtInput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($input)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Please enter at least one device name, OU path, or group name.',
                'Input Required',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        # Disable controls during search
        $btnSearch.Enabled     = $false
        $btnExportCsv.Enabled  = $false
        $btnExportExcel.Enabled = $false
        $btnCopyTable.Enabled  = $false
        $script:AllRows.Clear()
        $grid.Rows.Clear()
        & $detailResult.ClearDetails
        $splitContainer.Panel2Collapsed = $true

        try {
            # ── Mode: OU lookup ──────────────────────────────────────────────
            if ($rbOU.Checked) {
                Set-Status 'Querying Active Directory OU…' -Progress 10
                $devices = Get-DevicesByOU -OUDistinguishedName $input
                $total = $devices.Count
                if ($total -eq 0) {
                    Set-Status "No devices found in OU: $input"
                    return
                }
                $i = 0
                foreach ($dev in $devices) {
                    $i++
                    Set-Status "Enriching device $i of $total…" -Progress ([int](($i / $total) * 90))
                    $owner  = Get-DeviceOwner -DeviceObjectId $dev.id
                    $intune = $null
                    try { $intune = Get-DeviceIntuneDetails -DeviceId $dev.deviceId } catch {}
                    Add-ResultRow -RowData (Format-DeviceRow -Device $dev -Owner $owner -Intune $intune)
                }
            }

            # ── Mode: Entra Group lookup ─────────────────────────────────────
            elseif ($rbGroup.Checked) {
                Set-Status "Querying Entra group '$input'…" -Progress 10
                $devices = Get-DevicesInGroup -GroupName $input
                $total = $devices.Count
                if ($total -eq 0) {
                    Set-Status "No devices found in group: $input"
                    return
                }
                $i = 0
                foreach ($dev in $devices) {
                    $i++
                    Set-Status "Enriching device $i of $total…" -Progress ([int](($i / $total) * 90))
                    $owner  = Get-DeviceOwner -DeviceObjectId $dev.id
                    $intune = $null
                    try { $intune = Get-DeviceIntuneDetails -DeviceId $dev.deviceId } catch {}
                    Add-ResultRow -RowData (Format-DeviceRow -Device $dev -Owner $owner -Intune $intune)
                }
            }

            # ── Mode: Computer name(s) ────────────────────────────────────────
            else {
                # Split on commas and/or newlines
                $names = $input -split '[,\r\n]+' |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -ne '' } |
                    Select-Object -Unique

                Set-Status "Searching for $($names.Count) device(s)…" -Progress 5

                $devices = Get-DevicesByNames -Names $names
                $total   = $devices.Count

                if ($total -eq 0) {
                    Set-Status "No matching devices found."
                    return
                }

                $i = 0
                foreach ($dev in $devices) {
                    $i++
                    Set-Status "Enriching device $i of $total…" -Progress ([int](5 + ($i / $total) * 85))
                    $owner  = Get-DeviceOwner -DeviceObjectId $dev.id
                    $intune = $null
                    try { $intune = Get-DeviceIntuneDetails -DeviceId $dev.deviceId } catch {}
                    Add-ResultRow -RowData (Format-DeviceRow -Device $dev -Owner $owner -Intune $intune)
                }
            }

            Update-Grid -Filter $txtFilter.Text
            Set-Status "Done – $($script:AllRows.Count) device(s) loaded at $(Get-Date -Format 'HH:mm:ss')"

        } catch {
            Set-Status "Error: $_"
            [System.Windows.Forms.MessageBox]::Show(
                "An error occurred during the search:`n`n$_",
                'Search Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        } finally {
            $btnSearch.Enabled      = $true
            $btnExportCsv.Enabled   = $true
            $btnExportExcel.Enabled = $true
            $btnCopyTable.Enabled   = $true
            $progressBar.Visible    = $false
        }
    })

    # Also trigger search on Enter key inside the input box
    $txtInput.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Return) {
            $btnSearch.PerformClick()
            $e.SuppressKeyPress = $true
        }
    })

    # -------------------------------------------------------------------------
    # Client-side filter
    # -------------------------------------------------------------------------
    $txtFilter.Add_TextChanged({
        Update-Grid -Filter $txtFilter.Text
    })

    # -------------------------------------------------------------------------
    # Row selection → detail panel
    # -------------------------------------------------------------------------
    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -eq 0) {
            & $detailResult.ClearDetails
            $splitContainer.Panel2Collapsed = $true
            return
        }
        $row = $grid.SelectedRows[0]

        # Build rowData hashtable from grid cells
        $rowData = @{}
        foreach ($col in $grid.Columns) {
            $rowData[$col.Name] = $row.Cells[$col.Index].Value
        }

        & $detailResult.UpdateDetails -RowData $rowData
        $splitContainer.Panel2Collapsed = $false
    })

    # -------------------------------------------------------------------------
    # Export / action buttons
    # -------------------------------------------------------------------------
    $btnExportCsv.Add_Click({
        $path = Export-ResultsToCsv -Grid $grid -OwnerForm $form
        if ($path) { Set-Status "Exported to: $path" }
    })

    $btnExportExcel.Add_Click({
        $path = Export-ResultsToExcel -Grid $grid -OwnerForm $form
        if ($path) { Set-Status "Exported to: $path" }
    })

    $btnCopyTable.Add_Click({
        $ok = Copy-GridToClipboard -Grid $grid
        if ($ok) { Set-Status 'Table copied to clipboard.' }
    })

    $btnClear.Add_Click({
        $script:AllRows.Clear()
        $grid.Rows.Clear()
        $txtInput.Clear()
        $txtFilter.Clear()
        & $detailResult.ClearDetails
        $splitContainer.Panel2Collapsed = $true
        Set-Status 'Cleared.'
        $lblResultCount.Text = '0 devices'
    })

    # -------------------------------------------------------------------------
    # Theme toggle
    # -------------------------------------------------------------------------
    $btnTheme.Add_Click({
        $newTheme = Toggle-Theme
        if ($newTheme -eq 'Dark') {
            $btnTheme.Text = '☀️ Light Mode'
        } else {
            $btnTheme.Text = '🌙 Dark Mode'
        }
        Apply-ThemeToForm -Control $form
        Update-Grid -Filter $txtFilter.Text
    })

    # -------------------------------------------------------------------------
    # Keyboard shortcuts
    # -------------------------------------------------------------------------
    $form.Add_KeyDown({
        param($s, $e)
        switch ($e.KeyCode) {
            'F5'  { $btnSearch.PerformClick(); $e.SuppressKeyPress = $true }
            'E'   { if ($e.Control) { $btnExportCsv.PerformClick(); $e.SuppressKeyPress = $true } }
            'F'   { if ($e.Control) { $txtFilter.Focus(); $e.SuppressKeyPress = $true } }
        }
    })

    # -------------------------------------------------------------------------
    # Assemble and display
    # -------------------------------------------------------------------------
    $form.Controls.Add($splitContainer)
    $form.Controls.Add($toolPanel)
    $form.Controls.Add($searchPanel)
    $form.Controls.Add($statusBar)

    # Apply initial theme
    Apply-ThemeToForm -Control $form
    # Accent button: override theme application for accent-tagged buttons
    $btnSearch.BackColor = Get-ThemeColor 'Accent'
    $btnSearch.ForeColor = [System.Drawing.Color]::White

    Set-Status 'Ready – enter a device name and press Search (or F5).'

    # Show modal
    [System.Windows.Forms.Application]::Run($form)
}
