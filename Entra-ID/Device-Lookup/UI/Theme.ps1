#Requires -Version 5.1
<#
.SYNOPSIS
    Colour constants and theme helpers for the Entra ID Device Info Lookup Tool.

.DESCRIPTION
    Provides Dark and Light colour palettes (Microsoft Fluent-inspired) and helper
    functions to apply them to WinForms controls.
#>

Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# Palette definitions
# ---------------------------------------------------------------------------
$Script:Palettes = @{
    Dark = @{
        Background    = [System.Drawing.Color]::FromArgb(30, 30, 46)
        Surface       = [System.Drawing.Color]::FromArgb(40, 40, 60)
        SurfaceAlt    = [System.Drawing.Color]::FromArgb(35, 35, 52)
        Accent        = [System.Drawing.Color]::FromArgb(0, 120, 212)
        AccentHover   = [System.Drawing.Color]::FromArgb(0, 100, 180)
        Text          = [System.Drawing.Color]::FromArgb(220, 220, 235)
        TextSecondary = [System.Drawing.Color]::FromArgb(150, 150, 170)
        Success       = [System.Drawing.Color]::FromArgb(16, 124, 16)
        SuccessBg     = [System.Drawing.Color]::FromArgb(25, 60, 25)
        Warning       = [System.Drawing.Color]::FromArgb(202, 80, 16)
        WarningBg     = [System.Drawing.Color]::FromArgb(70, 35, 10)
        Disabled      = [System.Drawing.Color]::FromArgb(80, 80, 100)
        DisabledBg    = [System.Drawing.Color]::FromArgb(45, 45, 65)
        Border        = [System.Drawing.Color]::FromArgb(60, 60, 80)
        GridHeader    = [System.Drawing.Color]::FromArgb(0, 90, 160)
        Stale         = [System.Drawing.Color]::FromArgb(70, 65, 10)
    }
    Light = @{
        Background    = [System.Drawing.Color]::FromArgb(245, 247, 250)
        Surface       = [System.Drawing.Color]::White
        SurfaceAlt    = [System.Drawing.Color]::FromArgb(248, 250, 253)
        Accent        = [System.Drawing.Color]::FromArgb(0, 120, 212)
        AccentHover   = [System.Drawing.Color]::FromArgb(0, 100, 180)
        Text          = [System.Drawing.Color]::FromArgb(32, 32, 32)
        TextSecondary = [System.Drawing.Color]::FromArgb(100, 100, 110)
        Success       = [System.Drawing.Color]::FromArgb(16, 124, 16)
        SuccessBg     = [System.Drawing.Color]::FromArgb(220, 255, 220)
        Warning       = [System.Drawing.Color]::FromArgb(202, 80, 16)
        WarningBg     = [System.Drawing.Color]::FromArgb(255, 230, 210)
        Disabled      = [System.Drawing.Color]::FromArgb(140, 140, 150)
        DisabledBg    = [System.Drawing.Color]::FromArgb(240, 240, 245)
        Border        = [System.Drawing.Color]::FromArgb(210, 215, 225)
        GridHeader    = [System.Drawing.Color]::FromArgb(0, 120, 212)
        Stale         = [System.Drawing.Color]::FromArgb(255, 250, 180)
    }
}

# Active theme name – starts in Dark mode
$Script:ActiveTheme = 'Dark'

# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

function Get-ThemeColor {
    <#
    .SYNOPSIS
        Returns the System.Drawing.Color for the given semantic colour name in
        the currently active theme.
    .EXAMPLE
        $bg = Get-ThemeColor 'Background'
    #>
    param(
        [Parameter(Mandatory)][string]$ColorName
    )
    return $Script:Palettes[$Script:ActiveTheme][$ColorName]
}

function Set-ActiveTheme {
    <#
    .SYNOPSIS
        Switches the active theme to 'Dark' or 'Light'.
    #>
    param(
        [ValidateSet('Dark', 'Light')]
        [string]$ThemeName
    )
    $Script:ActiveTheme = $ThemeName
}

function Toggle-Theme {
    <#
    .SYNOPSIS
        Flips the active theme (Dark <-> Light). Returns the new theme name.
    #>
    if ($Script:ActiveTheme -eq 'Dark') {
        $Script:ActiveTheme = 'Light'
    } else {
        $Script:ActiveTheme = 'Dark'
    }
    return $Script:ActiveTheme
}

function Get-ActiveThemeName { return $Script:ActiveTheme }

function New-StyledButton {
    <#
    .SYNOPSIS
        Creates a flat, accent-coloured Windows Forms button styled for the active theme.
    #>
    param(
        [string]$Text,
        [int]$Width  = 110,
        [int]$Height = 32
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = $Text
    $btn.Width     = $Width
    $btn.Height    = $Height
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize  = 0
    $btn.BackColor = Get-ThemeColor 'Accent'
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font      = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
    $btn.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag       = 'accent'
    return $btn
}

function New-SecondaryButton {
    <#
    .SYNOPSIS
        Creates a flat, outlined secondary button styled for the active theme.
    #>
    param(
        [string]$Text,
        [int]$Width  = 110,
        [int]$Height = 32
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = $Text
    $btn.Width     = $Width
    $btn.Height    = $Height
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize  = 1
    $btn.FlatAppearance.BorderColor = Get-ThemeColor 'Border'
    $btn.BackColor  = Get-ThemeColor 'Surface'
    $btn.ForeColor  = Get-ThemeColor 'Text'
    $btn.Font       = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
    $btn.Cursor     = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

function Apply-ThemeToForm {
    <#
    .SYNOPSIS
        Recursively applies the active theme colours to a WinForms control and all
        its children. Recognises standard control types and applies sensible colours.
    #>
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control
    )
    $p = $Script:Palettes[$Script:ActiveTheme]

    switch ($Control.GetType().Name) {
        'Form' {
            $Control.BackColor = $p.Background
            $Control.ForeColor = $p.Text
        }
        { $_ -in @('Panel', 'FlowLayoutPanel', 'TableLayoutPanel') } {
            $Control.BackColor = $p.Background
            $Control.ForeColor = $p.Text
        }
        'GroupBox' {
            $Control.BackColor = $p.Background
            $Control.ForeColor = $p.TextSecondary
        }
        'Label' {
            $Control.BackColor = [System.Drawing.Color]::Transparent
            $Control.ForeColor = $p.Text
        }
        'TextBox' {
            $Control.BackColor   = $p.Surface
            $Control.ForeColor   = $p.Text
            $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        }
        'RichTextBox' {
            $Control.BackColor = $p.Surface
            $Control.ForeColor = $p.Text
        }
        'RadioButton' {
            $Control.BackColor = [System.Drawing.Color]::Transparent
            $Control.ForeColor = $p.Text
        }
        'CheckBox' {
            $Control.BackColor = [System.Drawing.Color]::Transparent
            $Control.ForeColor = $p.Text
        }
        'Button' {
            if ($Control.Tag -ne 'accent') {
                $Control.FlatAppearance.BorderColor = $p.Border
                $Control.BackColor = $p.Surface
                $Control.ForeColor = $p.Text
            }
        }
        'DataGridView' {
            $Control.BackgroundColor = $p.Background
            $Control.GridColor       = $p.Border
            $Control.DefaultCellStyle.BackColor          = $p.Surface
            $Control.DefaultCellStyle.ForeColor          = $p.Text
            $Control.DefaultCellStyle.SelectionBackColor = $p.Accent
            $Control.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
            $Control.AlternatingRowsDefaultCellStyle.BackColor     = $p.SurfaceAlt
            $Control.ColumnHeadersDefaultCellStyle.BackColor       = $p.GridHeader
            $Control.ColumnHeadersDefaultCellStyle.ForeColor       = [System.Drawing.Color]::White
            $Control.ColumnHeadersDefaultCellStyle.Font            = New-Object System.Drawing.Font(
                'Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
            $Control.EnableHeadersVisualStyles = $false
        }
        'StatusStrip' {
            $Control.BackColor = $p.Surface
            $Control.ForeColor = $p.Text
        }
        'SplitContainer' {
            $Control.BackColor = $p.Border
        }
        'ListView' {
            $Control.BackColor = $p.Surface
            $Control.ForeColor = $p.Text
        }
    }

    foreach ($child in $Control.Controls) {
        Apply-ThemeToForm -Control $child
    }
}
