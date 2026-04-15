#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the expandable device-detail side panel for the Entra ID Device Lookup Tool.

.DESCRIPTION
    Provides a single public function, New-DetailPanel, which returns a Panel
    control (initially hidden) that is shown when the user selects a row in the
    DataGridView.  It renders all device attributes as a tidy key→value list and
    exposes quick-action buttons (Open in Entra Portal, Copy Device ID).
#>

function New-DetailPanel {
    <#
    .SYNOPSIS
        Creates and returns the detail Panel control.

    .PARAMETER PanelWidth
        Width of the panel in pixels.

    .PARAMETER GetThemeColor
        ScriptBlock that accepts a colour name string and returns the matching
        System.Drawing.Color. Usually: { param($n) Get-ThemeColor $n }

    .OUTPUTS
        A [hashtable] containing:
          Panel          – the Panel control itself
          UpdateDetails  – ScriptBlock: call with a row-data hashtable to populate the panel
          ClearDetails   – ScriptBlock: clears all content
    #>
    param(
        [int]$PanelWidth      = 340,
        [scriptblock]$GetColor = { param($n) [System.Drawing.Color]::Gray }
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # -----------------------------------------------------------------------
    # Panel container
    # -----------------------------------------------------------------------
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Width   = $PanelWidth
    $panel.Dock    = [System.Windows.Forms.DockStyle]::Right
    $panel.Padding = New-Object System.Windows.Forms.Padding(10)
    $panel.Visible = $false

    # Title label
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'Device Details'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize  = $false
    $lblTitle.Width     = $PanelWidth - 20
    $lblTitle.Height    = 28
    $lblTitle.Location  = New-Object System.Drawing.Point(10, 10)
    $lblTitle.BackColor = [System.Drawing.Color]::Transparent

    # Separator line
    $separator = New-Object System.Windows.Forms.Label
    $separator.Height    = 1
    $separator.Width     = $PanelWidth - 20
    $separator.Location  = New-Object System.Drawing.Point(10, 42)
    $separator.BackColor = & $GetColor 'Border'

    # Scrollable content panel for the key-value rows
    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Location  = New-Object System.Drawing.Point(10, 50)
    $scrollPanel.Width     = $PanelWidth - 20
    $scrollPanel.Height    = 360
    $scrollPanel.AutoScroll = $true
    $scrollPanel.BackColor  = [System.Drawing.Color]::Transparent

    # Quick-action button strip at the bottom
    $btnOpenPortal = New-Object System.Windows.Forms.Button
    $btnOpenPortal.Text      = '🌐 Open in Entra Portal'
    $btnOpenPortal.Width     = $PanelWidth - 20
    $btnOpenPortal.Height    = 30
    $btnOpenPortal.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOpenPortal.FlatAppearance.BorderSize = 0
    $btnOpenPortal.Font      = New-Object System.Drawing.Font('Segoe UI', 9)
    $btnOpenPortal.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btnOpenPortal.Tag       = 'accent'
    $btnOpenPortal.Enabled   = $false

    $btnCopyId = New-Object System.Windows.Forms.Button
    $btnCopyId.Text      = '📋 Copy Device ID'
    $btnCopyId.Width     = $PanelWidth - 20
    $btnCopyId.Height    = 30
    $btnCopyId.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopyId.FlatAppearance.BorderSize = 1
    $btnCopyId.Font      = New-Object System.Drawing.Font('Segoe UI', 9)
    $btnCopyId.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btnCopyId.Enabled   = $false

    # Anchor buttons near the bottom of the panel
    $btnOpenPortal.Location = New-Object System.Drawing.Point(10, 425)
    $btnCopyId.Location     = New-Object System.Drawing.Point(10, 462)

    $panel.Controls.AddRange(@($lblTitle, $separator, $scrollPanel, $btnOpenPortal, $btnCopyId))

    # -----------------------------------------------------------------------
    # Helper: build one key-value row inside the scroll panel
    # -----------------------------------------------------------------------
    $rowY = 0
    function Add-DetailRow {
        param([string]$Key, [string]$Value)
        $keyLabel = New-Object System.Windows.Forms.Label
        $keyLabel.Text      = $Key
        $keyLabel.Font      = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
        $keyLabel.AutoSize  = $false
        $keyLabel.Width     = 130
        $keyLabel.Height    = 18
        $keyLabel.Location  = New-Object System.Drawing.Point(0, $rowY)
        $keyLabel.BackColor = [System.Drawing.Color]::Transparent
        $keyLabel.ForeColor = & $GetColor 'TextSecondary'

        $valLabel = New-Object System.Windows.Forms.Label
        $valLabel.Text      = if ($Value) { $Value } else { '—' }
        $valLabel.Font      = New-Object System.Drawing.Font('Segoe UI', 8)
        $valLabel.AutoSize  = $false
        $valLabel.Width     = $scrollPanel.Width - 135
        $valLabel.Height    = 18
        $valLabel.Location  = New-Object System.Drawing.Point(135, $rowY)
        $valLabel.BackColor = [System.Drawing.Color]::Transparent

        $scrollPanel.Controls.Add($keyLabel)
        $scrollPanel.Controls.Add($valLabel)
        Set-Variable -Name rowY -Value ($rowY + 22) -Scope 1
    }

    # -----------------------------------------------------------------------
    # ScriptBlock: populate the panel from a row-data hashtable
    # -----------------------------------------------------------------------
    $UpdateDetails = {
        param([hashtable]$RowData)

        $scrollPanel.Controls.Clear()
        $rowY = 0

        $displayRows = [ordered]@{
            'Display Name'    = $RowData['Name']
            'Join Type'       = $RowData['Join Type']
            'Trust Type'      = $RowData['_TrustType']
            'Owner'           = $RowData['Owner']
            'Owner UPN'       = $RowData['_OwnerUPN']
            'MDM Enrolled'    = $RowData['MDM Enrolled']
            'Compliant'       = $RowData['Compliant']
            'Intune State'    = $RowData['_IntuneState']
            'Encrypted'       = if ($null -ne $RowData['_IntuneEncrypt']) {
                                    if ($RowData['_IntuneEncrypt']) { '✅ Yes' } else { '❌ No' }
                                } else { '—' }
            'OS'              = $RowData['OS']
            'Enabled'         = $RowData['Enabled']
            'Registration'    = $RowData['Reg. Date']
            'Last Activity'   = $RowData['Last Active']
            'Stale (90+ days)'= if ($RowData['_IsStale']) { '⚠️ Yes' } else { 'No' }
            'Device ID'       = $RowData['_DeviceId']
            'Object ID'       = $RowData['_ObjectId']
        }

        foreach ($kv in $displayRows.GetEnumerator()) {
            Add-DetailRow -Key $kv.Key -Value ([string]$kv.Value)
        }

        # Wire up action buttons
        $objectId = $RowData['_ObjectId']
        $deviceId = $RowData['_DeviceId']

        if ($objectId) {
            $btnOpenPortal.Enabled   = $true
            $btnOpenPortal.BackColor = & $GetColor 'Accent'
            $btnOpenPortal.ForeColor = [System.Drawing.Color]::White
            $btnOpenPortal.Tag       = "accent|$objectId"
        }

        if ($deviceId) {
            $btnCopyId.Enabled   = $true
            $btnCopyId.BackColor = & $GetColor 'Surface'
            $btnCopyId.ForeColor = & $GetColor 'Text'
            $btnCopyId.FlatAppearance.BorderColor = & $GetColor 'Border'
            $btnCopyId.Tag       = $deviceId
        }

        $lblTitle.ForeColor = & $GetColor 'Text'
        $panel.Visible = $true
    }

    # -----------------------------------------------------------------------
    # ScriptBlock: clear the panel
    # -----------------------------------------------------------------------
    $ClearDetails = {
        $scrollPanel.Controls.Clear()
        $btnOpenPortal.Enabled = $false
        $btnCopyId.Enabled     = $false
        $panel.Visible         = $false
    }

    # -----------------------------------------------------------------------
    # Button event handlers (registered once at build time)
    # -----------------------------------------------------------------------
    $btnOpenPortal.Add_Click({
        $tag = $btnOpenPortal.Tag
        if ($tag -and $tag -match '\|(.+)$') {
            $oid = $Matches[1]
            $url = "https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DeviceDetailsMenuBlade/~/Properties/objectId/$oid"
            Start-Process $url
        }
    })

    $btnCopyId.Add_Click({
        $id = $btnCopyId.Tag
        if ($id) {
            [System.Windows.Forms.Clipboard]::SetText($id)
            $originalText        = $btnCopyId.Text
            $btnCopyId.Text      = '✅ Copied!'
            $btnCopyId.Enabled   = $false
            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 1500
            $timer.Add_Tick({
                $btnCopyId.Text    = $originalText
                $btnCopyId.Enabled = $true
                $timer.Stop()
                $timer.Dispose()
            })
            $timer.Start()
        }
    })

    return @{
        Panel         = $panel
        UpdateDetails = $UpdateDetails
        ClearDetails  = $ClearDetails
    }
}
