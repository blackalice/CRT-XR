$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tools = Join-Path $root 'tools'
New-Item -ItemType Directory -Force $tools | Out-Null
New-Item -ItemType File -Force (Join-Path $tools '.gdignore') | Out-Null
$archive = Join-Path $tools 'godot.zip'
Invoke-WebRequest 'https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip' -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $tools 'godot') -Force
New-Item -ItemType File -Force (Join-Path $tools 'godot/_sc_') | Out-Null
Write-Host 'Godot 4.5.1 ready. Run ./scripts/dev.ps1'
