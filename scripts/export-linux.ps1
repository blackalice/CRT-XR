param([string]$Godot = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe' }
$out = Join-Path $root 'dist/linux'
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType File -Force (Join-Path $root 'dist/.gdignore') | Out-Null
$env:APPDATA = Join-Path $root 'tools/userdata'
& $Godot --headless --path $root --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
& $Godot --headless --path $root --export-release 'Linux x86_64' (Join-Path $out 'retrocrt.x86_64')
if ($LASTEXITCODE -ne 0) { throw 'Linux export failed. Install matching Godot 4.5.1 export templates in Editor > Manage Export Templates.' }
Move-Item -LiteralPath (Join-Path $out 'retrocrt.x86_64') -Destination (Join-Path $out 'retrocrt-engine.x86_64') -Force
Copy-Item -LiteralPath (Join-Path $root 'scripts/linux-runtime.sh') -Destination (Join-Path $out 'retrocrt.x86_64')
Copy-Item -LiteralPath (Join-Path $root 'scripts/launch-deck.sh') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/launch-steam.sh') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/steam-session.py') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/launch-glasses.sh') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/glasses-session.py') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/driver-sbs.py') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'docs/display-setup.md') -Destination (Join-Path $out 'DISPLAY-SETUP.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/emulation.md') -Destination (Join-Path $out 'PLAYING.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/gaming-mode.md') -Destination (Join-Path $out 'GAMING-MODE.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/input-latency.md') -Destination (Join-Path $out 'INPUT-LATENCY.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/room-and-view.md') -Destination (Join-Path $out 'ROOM-AND-VIEW.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/picture-controls.md') -Destination (Join-Path $out 'PICTURE-CONTROLS.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/screen-light.md') -Destination (Join-Path $out 'SCREEN-LIGHT.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/crt-performance.md') -Destination (Join-Path $out 'CRT-PERFORMANCE.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/settings-and-startup.md') -Destination (Join-Path $out 'SETTINGS-AND-STARTUP.md')
Copy-Item -LiteralPath (Join-Path $root 'docs/audio.md') -Destination (Join-Path $out 'AUDIO.md')
New-Item -ItemType Directory -Force (Join-Path $out 'licenses/audio') | Out-Null
Copy-Item -Path (Join-Path $root 'third_party/audio/*') -Destination (Join-Path $out 'licenses/audio')
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY.md') -Destination $out
$shaderNotices = Join-Path $out 'licenses/shaders'
New-Item -ItemType Directory -Force $shaderNotices | Out-Null
Copy-Item -Path (Join-Path $root 'third_party/shaders/*') -Destination $shaderNotices
$cabinet = Join-Path $root 'build/crt-model/crt_tv.glb'
$prepared = Join-Path $root 'build/crt-model/optimised'
if ((Test-Path -LiteralPath $cabinet) -or (Test-Path -LiteralPath (Join-Path $prepared 'cabinet.scn'))) {
    $assetOut = Join-Path $out 'assets'
    New-Item -ItemType Directory -Force $assetOut | Out-Null
    if (Test-Path -LiteralPath (Join-Path $prepared 'cabinet.scn')) {
        Copy-Item -LiteralPath $prepared -Destination $assetOut -Recurse -Force
        Remove-Item -LiteralPath (Join-Path $assetOut 'crt_tv.glb') -ErrorAction SilentlyContinue
    } else { Copy-Item -LiteralPath $cabinet -Destination (Join-Path $assetOut 'crt_tv.glb') }
    Copy-Item -LiteralPath (Join-Path $root 'docs/crt-model-local.md') -Destination (Join-Path $assetOut 'CRT-MODEL.md')
    $ao = Join-Path $root 'build/crt-model/ao'
    if (Test-Path -LiteralPath $ao) {
        New-Item -ItemType Directory -Force (Join-Path $assetOut 'ao') | Out-Null
        Copy-Item -Path (Join-Path $ao '*_ao.png') -Destination (Join-Path $assetOut 'ao')
        Copy-Item -LiteralPath (Join-Path $ao 'bake.json') -Destination (Join-Path $assetOut 'ao')
    }
}
$allCores = @('snes9x','nestopia','genesis_plus_gx')
foreach ($coreName in $allCores) {
    $core = Join-Path $root "cores/${coreName}_libretro.so"
    if (-not (Test-Path -LiteralPath $core)) { throw "Missing emulator core: $coreName" }
}
if ($allCores.Count -gt 0) {
    $coreOut = Join-Path $out 'cores'
    New-Item -ItemType Directory -Force $coreOut | Out-Null
    foreach ($coreName in $allCores) {
        Copy-Item -LiteralPath (Join-Path $root "cores/${coreName}_libretro.so") -Destination $coreOut
    }
    Copy-Item -LiteralPath (Join-Path $root 'cores/sources') -Destination $coreOut -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $root 'cores/core-builds.json') -Destination $coreOut
    Copy-Item -Path (Join-Path $root 'cores/*LICENSE*') -Destination $coreOut
    Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY.md') -Destination $out
    Copy-Item -LiteralPath (Join-Path $root 'extensions/bin/godot-cpp-LICENSE.md') -Destination $out
} else {
    Write-Warning 'Snes9x core missing: build emulation dependencies to include gameplay.'
}
Write-Host "Linux package: $out"
