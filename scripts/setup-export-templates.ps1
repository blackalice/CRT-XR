param([string]$Archive)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force (Join-Path $root 'tools') | Out-Null
New-Item -ItemType File -Force (Join-Path $root 'tools/.gdignore') | Out-Null
if (-not $Archive) { $Archive = Join-Path $root 'tools/export_templates.zip' }
if (-not (Test-Path -LiteralPath $Archive)) {
    Invoke-WebRequest 'https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz' -OutFile $Archive
}
# Portable Godot installed by setup-windows.ps1 stores templates here.
$destination = Join-Path $root 'tools/godot/editor_data/export_templates/4.5.1.stable'
New-Item -ItemType Directory -Force $destination | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($Archive)
try {
    foreach ($name in @('linux_release.x86_64', 'linux_debug.x86_64', 'version.txt')) {
        $entry = $zip.GetEntry("templates/$name")
        if (-not $entry) { throw "Template archive missing $name" }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $destination $name), $true)
    }
} finally { $zip.Dispose() }
Write-Host 'Linux export templates installed for bundled portable Godot.'
