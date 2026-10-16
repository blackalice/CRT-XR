param([string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root 'build/room-bake-user'
& (Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe') --headless --path $root --script res://scripts/export-room-bake.gd
if ($LASTEXITCODE -ne 0) { throw 'Room geometry export failed' }
& $Blender --background --factory-startup --python (Join-Path $root 'scripts/bake-room-contacts.py')
if ($LASTEXITCODE -ne 0) { throw 'Room contact bake failed' }
& (Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe') --headless --path $root --script res://scripts/prepare-contact-material.gd
if ($LASTEXITCODE -ne 0) { throw 'Contact material preparation failed' }
Write-Host 'Updated table and carpet contact maps in build/room-bake. Export a new build to package them.'
