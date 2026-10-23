param([string]$OutputDirectory = 'dist/windows')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe'
$out = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force $out | Out-Null
$env:APPDATA = Join-Path $root 'tools/userdata'
& $godot --headless --path $root --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
& $godot --headless --path $root --export-release 'Windows Desktop' (Join-Path $out 'CRT-XR.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
# Keep the PCK separate so manifest edits cannot relocate embedded game data.
& python (Join-Path $root 'scripts/set-windows-dpi.py') (Join-Path $out 'CRT-XR.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows DPI manifest update failed.' }
New-Item -ItemType Directory -Force (Join-Path $out 'cores'), (Join-Path $out 'assets'), (Join-Path $out 'licenses/shaders') | Out-Null
foreach ($core in @('snes9x','nestopia','genesis_plus_gx','gambatte','mgba','mednafen_pce_fast','mednafen_lynx','mednafen_ngp','stella','vecx')) {
    Copy-Item -LiteralPath (Join-Path $root "cores/${core}_libretro.dll") -Destination (Join-Path $out 'cores')
}
Copy-Item -Path (Join-Path $root 'cores/*LICENSE*') -Destination (Join-Path $out 'cores')
Copy-Item -LiteralPath (Join-Path $root 'cores/sources') -Destination (Join-Path $out 'cores') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'cores/core-builds.json') -Destination (Join-Path $out 'cores')
Copy-Item -LiteralPath (Join-Path $root 'docs/emulation.md') -Destination (Join-Path $out 'PLAYING.md')
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY.md') -Destination $out
foreach ($notice in @('LICENSE','LICENSING.md')) { Copy-Item -LiteralPath (Join-Path $root $notice) -Destination $out }
Copy-Item -LiteralPath (Join-Path $root 'docs/CORE-DISTRIBUTION.md') -Destination (Join-Path $out 'CORE-DISTRIBUTION.md')
New-Item -ItemType Directory -Force (Join-Path $out 'licenses/model-evidence') | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'docs/license-evidence/crt-tv.json') -Destination (Join-Path $out 'licenses/model-evidence/crt-tv.json')
Copy-Item -LiteralPath (Join-Path $root 'extensions/bin/godot-cpp-LICENSE.md') -Destination $out
Copy-Item -Path (Join-Path $root 'third_party/shaders/*') -Destination (Join-Path $out 'licenses/shaders')
$model = Join-Path $root 'build/crt-model/crt_tv.glb'
$prepared = Join-Path $root 'build/crt-model/optimised'
if ((Test-Path -LiteralPath $model) -or (Test-Path -LiteralPath (Join-Path $prepared 'cabinet.scn'))) {
    if (Test-Path -LiteralPath (Join-Path $prepared 'cabinet.scn')) {
        Copy-Item -LiteralPath $prepared -Destination (Join-Path $out 'assets') -Recurse -Force
        Remove-Item -LiteralPath (Join-Path $out 'assets/crt_tv.glb') -ErrorAction SilentlyContinue
    } else { Copy-Item -LiteralPath $model -Destination (Join-Path $out 'assets/crt_tv.glb') }
    Copy-Item -LiteralPath (Join-Path $root 'docs/crt-model-local.md') -Destination (Join-Path $out 'assets/CRT-MODEL.md')
    $ao = Join-Path $root 'build/crt-model/ao'
    if (Test-Path -LiteralPath $ao) {
        New-Item -ItemType Directory -Force (Join-Path $out 'assets/ao') | Out-Null
        Copy-Item -Path (Join-Path $ao '*_ao.res') -Destination (Join-Path $out 'assets/ao')
        Copy-Item -LiteralPath (Join-Path $ao 'bake.json') -Destination (Join-Path $out 'assets/ao')
    }
}
Copy-Item -LiteralPath (Join-Path $root 'docs/room-and-view.md') -Destination (Join-Path $out 'ROOM-AND-VIEW.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/settings-and-startup.md') -Destination (Join-Path $out 'MENU-AND-SETTINGS.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/audio.md') -Destination (Join-Path $out 'AUDIO.md')
New-Item -ItemType Directory -Force (Join-Path $out 'licenses/audio') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $out 'licenses/fonts') | Out-Null
Copy-Item -Path (Join-Path $root 'third_party/fonts/*') -Destination (Join-Path $out 'licenses/fonts')
Copy-Item -Path (Join-Path $root 'third_party/audio/*') -Destination (Join-Path $out 'licenses/audio')
$table = Join-Path $root 'build/wood-table'
if (Test-Path -LiteralPath (Join-Path $table 'table.scn')) {
    New-Item -ItemType Directory -Force (Join-Path $out 'assets') | Out-Null
    Copy-Item -LiteralPath $table -Destination (Join-Path $out 'assets') -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $root 'docs/wood-table.md') -Destination (Join-Path $out 'assets/WOOD-TABLE.md')
}
$godotNotices = Join-Path $out 'licenses/godot'
New-Item -ItemType Directory -Force $godotNotices | Out-Null
Copy-Item -Path (Join-Path $root 'third_party/godot/*') -Destination $godotNotices
foreach ($document in @('BETA-REVIEW.md','BETA-QUICKSTART.md')) {
    Copy-Item -LiteralPath (Join-Path $root "docs/$document") -Destination $out
}
Copy-Item -LiteralPath (Join-Path $root 'assets/model-sources.json') -Destination (Join-Path $out 'assets')
# Remove only known stale console payload files when reusing an export folder.
$oldConsole = Join-Path $out 'assets/console'
if (Test-Path -LiteralPath $oldConsole) {
    $resolvedConsole = [IO.Path]::GetFullPath($oldConsole)
    $resolvedOutput = [IO.Path]::GetFullPath($out).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedConsole.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) { throw 'Console cleanup escaped export folder.' }
    foreach ($name in @('console.scn','manifest.json','CREDITS-AND-PREPARATION.md')) {
        Remove-Item -LiteralPath (Join-Path $oldConsole $name) -ErrorAction SilentlyContinue
    }
    if (@(Get-ChildItem -LiteralPath $oldConsole -Force).Count -ne 0) { throw 'Unexpected files remain in exported console folder; inspect before cleanup.' }
    Remove-Item -LiteralPath $oldConsole
}
$roomBake = Join-Path $root 'build/room-bake'
if (Test-Path -LiteralPath (Join-Path $roomBake 'bake.json')) {
    $bakeOut = Join-Path $out 'assets/room-bake'
    New-Item -ItemType Directory -Force $bakeOut | Out-Null
    foreach ($name in @('floor_ao.png','table_contact_albedo.res','bake.json')) {
        Copy-Item -LiteralPath (Join-Path $roomBake $name) -Destination $bakeOut
    }
    Copy-Item -LiteralPath (Join-Path $root 'docs/room-contact-bake.md') -Destination (Join-Path $out 'assets/ROOM-CONTACT-BAKE.md')
}
foreach ($name in @('GETTING-STARTED.md','PRE-LAUNCH-CHECKLIST.md','LICENCE-PROPOSAL.md')) {
    Copy-Item -LiteralPath (Join-Path $root "docs/$name") -Destination $out
}
$artworkOut = Join-Path $out 'artwork'
New-Item -ItemType Directory -Force $artworkOut | Out-Null
foreach ($name in @('Portrait.png','Landscape.png','Hero.png','Logo.png','Icon.png')) {
    Copy-Item -LiteralPath (Join-Path $root "artwork/$name") -Destination $artworkOut
}
# Vendor SDK is deliberately external until its redistribution terms are verified.
$trackingHelper = Join-Path $root 'build/windows-tracking/crt-xr-windows-tracking.exe'
if (Test-Path -LiteralPath $trackingHelper) {
    Copy-Item -LiteralPath $trackingHelper -Destination $out
}
Write-Host "Windows build: $out/CRT-XR.exe"

Copy-Item -LiteralPath (Join-Path $root "docs/WINDOWS-SETUP.md") -Destination $out
