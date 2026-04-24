#Requires -Version 5.1
<#
.SYNOPSIS
    M365 PowerShell Tool Portal – standalone GUI launcher.

.DESCRIPTION
    Opens a professional WinForms GUI shell that serves as the central portal for
    all M365 PowerShell tools in this repository. Each tool's data functions are
    loaded on demand from their respective subfolders and executed inside the portal.

    Tools available in the sidebar:
      - Get Intune Device Info  (Intune/Device-Management/Get-IntuneDeviceInfoTool.ps1)

.PARAMETER TenantId
    Optional tenant ID or domain used during Connect-MgGraph.

.PARAMETER SkipConnect
    Skip Graph sign-in when an authenticated Graph context already exists.

.EXAMPLE
    .\Start-M365ToolPortal.ps1

.EXAMPLE
    .\Start-M365ToolPortal.ps1 -TenantId 'contoso.onmicrosoft.com'

.NOTES
    File layout expected relative to this script:
      ../../Intune/Device-Management/Get-IntuneDeviceInfoTool.ps1
#>

[CmdletBinding()]
param(
    [string]$TenantId,
    [switch]$SkipConnect
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Resolve paths ────────────────────────────────────────────────────────────
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)

# ─── Load tool modules ────────────────────────────────────────────────────────
$intuneToolPath = Join-Path $RepoRoot 'Intune' 'Device-Management' 'Get-IntuneDeviceInfoTool.ps1'
if (-not (Test-Path $intuneToolPath)) {
    throw "Cannot find Intune device info tool at: $intuneToolPath"
}
. $intuneToolPath

# ─── Authentication ───────────────────────────────────────────────────────────
function Connect-ToolPortal {
    param(
        [string]$TenantId,
        [string[]]$Scopes = @('DeviceManagementManagedDevices.Read.All')
    )

    if (-not (Get-Module -Name Microsoft.Graph.Authentication -ListAvailable)) {
        throw "Missing required module 'Microsoft.Graph.Authentication'. Install it first: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $connectParams = @{ Scopes = $Scopes }
    if ($TenantId) { $connectParams.TenantId = $TenantId }

    Connect-MgGraph @connectParams -ErrorAction Stop | Out-Null
}

function Disconnect-ToolPortal {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}

# ─── GUI ──────────────────────────────────────────────────────────────────────
function Show-ToolPortal {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $theme = @{
        Background = [System.Drawing.Color]::FromArgb(23, 28, 36)
        Surface    = [System.Drawing.Color]::FromArgb(32, 39, 51)
        SurfaceAlt = [System.Drawing.Color]::FromArgb(38, 46, 60)
        Accent     = [System.Drawing.Color]::FromArgb(0, 120, 212)
        Border     = [System.Drawing.Color]::FromArgb(58, 67, 84)
        Text       = [System.Drawing.Color]::FromArgb(232, 236, 244)
        MutedText  = [System.Drawing.Color]::FromArgb(156, 165, 183)
    }

    # ── Main form ──────────────────────────────────────────────────────────────
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'M365 Tool Portal'
    $form.Size = New-Object System.Drawing.Size(1220, 760)
    $form.MinimumSize = New-Object System.Drawing.Size(950, 620)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.BackColor = $theme.Background
    $form.ForeColor = $theme.Text
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    # ── Header ─────────────────────────────────────────────────────────────────
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = [System.Windows.Forms.DockStyle]::Top
    $header.Height = 72
    $header.BackColor = $theme.Surface

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'M365 Tool Portal'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $theme.Text
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(16, 10)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = 'PowerShell Tool Portal  •  Select a tool from the list on the left'
    $subtitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $subtitle.ForeColor = $theme.MutedText
    $subtitle.AutoSize = $true
    $subtitle.Location = New-Object System.Drawing.Point(18, 42)

    $header.Controls.AddRange(@($title, $subtitle))

    # ── Status bar ─────────────────────────────────────────────────────────────
    $status = New-Object System.Windows.Forms.StatusStrip
    $status.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $status.BackColor = $theme.Surface
    $status.ForeColor = $theme.Text
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Spring = $true
    $statusLabel.Text = 'Ready'
    $status.Items.Add($statusLabel) | Out-Null

    # ── Split container: sidebar | content ─────────────────────────────────────
    $mainSplit = New-Object System.Windows.Forms.SplitContainer
    $mainSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainSplit.SplitterDistance = 220
    $mainSplit.BackColor = $theme.Border
    $mainSplit.Panel1.BackColor = $theme.Surface
    $mainSplit.Panel2.BackColor = $theme.Background

    # ── Tool list (sidebar) ────────────────────────────────────────────────────
    $toolList = New-Object System.Windows.Forms.ListBox
    $toolList.Dock = [System.Windows.Forms.DockStyle]::Fill
    $toolList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $toolList.BackColor = $theme.Surface
    $toolList.ForeColor = $theme.Text
    $toolList.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $toolList.Items.Add('Get Intune Device Info') | Out-Null
    $toolList.Items.Add('More tools coming soon…') | Out-Null
    $toolList.SelectedIndex = 0

    $mainSplit.Panel1.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainSplit.Panel1.Controls.Add($toolList)

    # ── Content panel (right side) ─────────────────────────────────────────────
    $toolPanel = New-Object System.Windows.Forms.Panel
    $toolPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $toolPanel.Padding = New-Object System.Windows.Forms.Padding(12)
    $toolPanel.BackColor = $theme.Background

    # ── Get Intune Device Info – controls ──────────────────────────────────────
    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = 'Search by device name, primary user, or serial number'
    $searchLabel.AutoSize = $true
    $searchLabel.ForeColor = $theme.MutedText
    $searchLabel.Location = New-Object System.Drawing.Point(12, 18)

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(12, 42)
    $searchBox.Width = 560
    $searchBox.BackColor = $theme.Surface
    $searchBox.ForeColor = $theme.Text
    $searchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $searchButton = New-Object System.Windows.Forms.Button
    $searchButton.Text = 'Search'
    $searchButton.Location = New-Object System.Drawing.Point(584, 40)
    $searchButton.Size = New-Object System.Drawing.Size(96, 28)
    $searchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $searchButton.FlatAppearance.BorderSize = 0
    $searchButton.BackColor = $theme.Accent
    $searchButton.ForeColor = [System.Drawing.Color]::White

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(12, 82)
    $grid.Size = New-Object System.Drawing.Size(850, 560)
    $grid.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Bottom,Left,Right'
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.ReadOnly = $true
    $grid.MultiSelect = $false
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.RowHeadersVisible = $false
    $grid.BackgroundColor = $theme.Surface
    $grid.GridColor = $theme.Border
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $theme.Accent
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $grid.DefaultCellStyle.BackColor = $theme.Surface
    $grid.DefaultCellStyle.ForeColor = $theme.Text
    $grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(0, 90, 170)
    $grid.AlternatingRowsDefaultCellStyle.BackColor = $theme.SurfaceAlt

    $detail = New-Object System.Windows.Forms.RichTextBox
    $detail.Location = New-Object System.Drawing.Point(874, 82)
    $detail.Size = New-Object System.Drawing.Size(290, 560)
    $detail.Anchor = [System.Windows.Forms.AnchorStyles]'Top,Bottom,Right'
    $detail.ReadOnly = $true
    $detail.BackColor = $theme.Surface
    $detail.ForeColor = $theme.Text
    $detail.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $detail.Text = 'Select a row to see device details.'

    $columns = @('Device Name', 'Primary User', 'OS', 'Compliance', 'Last Sync', 'Management Agent')
    foreach ($name in $columns) { [void]$grid.Columns.Add($name, $name) }

    # ── Event handlers ─────────────────────────────────────────────────────────
    $populateDetail = {
        if (-not $grid.CurrentRow) { return }
        $row    = $grid.CurrentRow
        $device = $row.Tag
        $serialNumber = if ($device) { Get-IntuneDisplayValue $device.serialNumber } else { '' }
        $manufacturer = if ($device) { Get-IntuneDisplayValue $device.manufacturer } else { '' }
        $model        = if ($device) { Get-IntuneDisplayValue $device.model }        else { '' }
        $enrolledDate = if ($device -and $device.enrolledDateTime) {
            ([datetime]$device.enrolledDateTime).ToString('yyyy-MM-dd HH:mm')
        } else { '' }

        $detail.Text = @"
Device Name: $($row.Cells['Device Name'].Value)
Primary User: $($row.Cells['Primary User'].Value)
OS: $($row.Cells['OS'].Value)
Compliance: $($row.Cells['Compliance'].Value)
Last Sync: $($row.Cells['Last Sync'].Value)
Management Agent: $($row.Cells['Management Agent'].Value)
Manufacturer: $manufacturer
Model: $model
Serial Number: $serialNumber
Enrolled: $enrolledDate
"@
    }

    $runSearch = {
        $searchValue = $searchBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($searchValue)) {
            $statusLabel.Text = 'Enter a search value first.'
            return
        }

        try {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $statusLabel.Text = "Searching Intune devices for '$searchValue'..."
            $grid.Rows.Clear()

            $results = Get-IntuneManagedDeviceInfo -SearchText $searchValue
            foreach ($device in @($results)) {
                $osParts = @($device.operatingSystem)
                if ($device.osVersion) { $osParts += $device.osVersion }
                $osText = $osParts -join ' '
                $lastSyncDisplay = if ($device.lastSyncDateTime) {
                    ([datetime]$device.lastSyncDateTime).ToString('yyyy-MM-dd HH:mm')
                } else { '' }
                $rowIndex = $grid.Rows.Add(
                    $device.deviceName,
                    $device.userPrincipalName,
                    $osText.Trim(),
                    $device.complianceState,
                    $lastSyncDisplay,
                    $device.managementAgent
                )
                $grid.Rows[$rowIndex].Tag = $device
            }

            $statusLabel.Text = "Loaded $($grid.Rows.Count) device(s)."
            if ($grid.Rows.Count -gt 0) {
                $grid.ClearSelection()
                $grid.Rows[0].Selected = $true
                & $populateDetail
            } else {
                $detail.Text = 'No devices found.'
            }
        } catch {
            $statusLabel.Text = 'Search failed.'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to query Intune devices:`n`n$_",
                'Search Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }

    $searchButton.Add_Click($runSearch)
    $searchBox.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $_.SuppressKeyPress = $true
            & $runSearch
        }
    })
    $grid.Add_SelectionChanged($populateDetail)

    $toolList.Add_SelectedIndexChanged({
        if ($toolList.SelectedIndex -ne 0) {
            $toolList.SelectedIndex = 0
            $statusLabel.Text = 'Only "Get Intune Device Info" is currently implemented.'
        }
    })

    $toolPanel.Controls.AddRange(@($searchLabel, $searchBox, $searchButton, $grid, $detail))
    $mainSplit.Panel2.Controls.Add($toolPanel)

    $form.Controls.AddRange(@($mainSplit, $status, $header))
    [void]$form.ShowDialog()
}

# ─── Entry point ──────────────────────────────────────────────────────────────
try {
    if (-not $SkipConnect) {
        Connect-ToolPortal -TenantId $TenantId
    }
    Show-ToolPortal
} finally {
    if (-not $SkipConnect) {
        Disconnect-ToolPortal
    }
}
