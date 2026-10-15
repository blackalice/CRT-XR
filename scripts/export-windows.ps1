param([string]$OutputDirectory = 'dist/windows')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe'
$out = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force $out | Out-Null
$env:APPDATA = Join-Path $root 'tools/userdata'
& $godot --headless --path $root --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
& $godot --headless --path $root --export-release 'Windows Desktop' (Join-Path $out 'RetroCRT.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
New-Item -ItemType Directory -Force (Join-Path $out 'cores'), (Join-Path $out 'assets'), (Join-Path $out 'licenses/shaders') | Out-Null
foreach ($core in @('snes9x','nestopia','genesis_plus_gx')) {
    Copy-Item -LiteralPath (Join-Path $root "cores/${core}_libretro.dll") -Destination (Join-Path $out 'cores')
}
Copy-Item -Path (Join-Path $root 'cores/*LICENSE*') -Destination (Join-Path $out 'cores')
Copy-Item -LiteralPath (Join-Path $root 'cores/sources') -Destination (Join-Path $out 'cores') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'cores/core-builds.json') -Destination (Join-Path $out 'cores')
Copy-Item -LiteralPath (Join-Path $root 'docs/emulation.md') -Destination (Join-Path $out 'PLAYING.md')
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY.md') -Destination $out
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
        Copy-Item -Path (Join-Path $ao '*_ao.png') -Destination (Join-Path $out 'assets/ao')
        Copy-Item -LiteralPath (Join-Path $ao 'bake.json') -Destination (Join-Path $out 'assets/ao')
    }
}
Copy-Item -LiteralPath (Join-Path $root 'docs/room-and-view.md') -Destination (Join-Path $out 'ROOM-AND-VIEW.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/settings-and-startup.md') -Destination (Join-Path $out 'MENU-AND-SETTINGS.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/audio.md') -Destination (Join-Path $out 'AUDIO.md')
New-Item -ItemType Directory -Force (Join-Path $out 'licenses/audio') | Out-Null
Copy-Item -Path (Join-Path $root 'third_party/audio/*') -Destination (Join-Path $out 'licenses/audio')
Write-Host "Windows build: $out/RetroCRT.exe"
