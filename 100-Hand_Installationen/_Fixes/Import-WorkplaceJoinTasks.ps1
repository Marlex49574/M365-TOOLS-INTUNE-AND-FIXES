#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Importiert die geplanten Tasks Device-Sync und Automatic-Device-Join in die Aufgabenplanung.

.DESCRIPTION
    Dieses Skript importiert die XML-Definitionen der Tasks Device-Sync.xml und Automatic-Device-Join.xml
    aus dem Netzwerkpfad \\install\install$\100-Hand_Installationen\_Fixes in den Ordner
    Aufgabenplanung\Microsoft\Windows\Workplace Join.

.NOTES
    Erfordert lokale Administratorrechte.
    Die XML-Dateien müssen unter \\install\install$\100-Hand_Installationen\_Fixes erreichbar sein.
#>

[CmdletBinding()]
param (
    [string]$SourcePath = '\\install\install$\100-Hand_Installationen\_Fixes',
    [string]$TaskFolder = '\Microsoft\Windows\Workplace Join'
)

$Tasks = @(
    @{ File = 'Device-Sync.xml';           Name = 'Device-Sync' },
    @{ File = 'Automatic-Device-Join.xml'; Name = 'Automatic-Device-Join' }
)

# Sicherstellen, dass der Zielordner in der Aufgabenplanung vorhanden ist
$Scheduler = New-Object -ComObject Schedule.Service
$Scheduler.Connect()

try {
    $Scheduler.GetFolder($TaskFolder) | Out-Null
    Write-Verbose "Aufgabenordner '$TaskFolder' ist bereits vorhanden."
} catch {
    Write-Host "Erstelle Aufgabenordner '$TaskFolder' ..."
    $RootFolder = $Scheduler.GetFolder('\')
    $RootFolder.CreateFolder($TaskFolder) | Out-Null
}

foreach ($Task in $Tasks) {
    $XmlFile = Join-Path -Path $SourcePath -ChildPath $Task.File

    if (-not (Test-Path -Path $XmlFile)) {
        Write-Warning "Datei nicht gefunden: $XmlFile — Task '$($Task.Name)' wird übersprungen."
        continue
    }

    Write-Host "Importiere Task '$($Task.Name)' aus '$XmlFile' ..."

    try {
        $XmlContent = Get-Content -Path $XmlFile -Raw -Encoding UTF8
        $Folder = $Scheduler.GetFolder($TaskFolder)
        # Flags: 6 = TASK_CREATE_OR_UPDATE | TASK_IGNORE_REGISTRATION_TRIGGERS
        $Folder.RegisterTask($Task.Name, $XmlContent, 6, $null, $null, 3, $null) | Out-Null
        Write-Host "  Task '$($Task.Name)' erfolgreich importiert." -ForegroundColor Green
    } catch {
        Write-Warning "  Fehler beim Importieren von Task '$($Task.Name)': $_"
    }
}

Write-Host "Fertig."
