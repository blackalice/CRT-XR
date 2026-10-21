param([string]$Godot = $env:GODOT_BIN, [string]$OutputDirectory = "dist/linux")
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe' }
$out = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType File -Force (Join-Path $root 'dist/.gdignore') | Out-Null
$env:APPDATA = Join-Path $root 'tools/userdata'
& $Godot --headless --path $root --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
& $Godot --headless --path $root --export-release 'Linux x86_64' (Join-Path $out 'crt-xr.x86_64')
if ($LASTEXITCODE -ne 0) { throw 'Linux export failed. Install matching Godot 4.5.1 export templates in Editor > Manage Export Templates.' }
Move-Item -LiteralPath (Join-Path $out 'crt-xr.x86_64') -Destination (Join-Path $out 'crt-xr-engine.x86_64') -Force
Copy-Item -LiteralPath (Join-Path $root 'scripts/linux-runtime.sh') -Destination (Join-Path $out 'crt-xr.x86_64')
foreach ($helper in @('crt-xr-tracking-bridge','crt-xr-ipc-inventory')) {
    $candidate = @((Join-Path $root "build/native-wsl/$helper"),(Join-Path $root "build/native/$helper"),(Join-Path $root "dist/linux/$helper")) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $candidate) { throw "Missing $helper; build Linux tracking helpers first." }
    if ([IO.Path]::GetFullPath($candidate) -ne [IO.Path]::GetFullPath((Join-Path $out $helper))) { Copy-Item -LiteralPath $candidate -Destination $out -Force }
}
Copy-Item -LiteralPath (Join-Path $root 'scripts/launch-deck.sh') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/launch-steam.sh') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/steam-session.py') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/tracking-session.py') -Destination $out
Copy-Item -LiteralPath (Join-Path $root 'scripts/display-probe.py') -Destination $out
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
foreach ($notice in @('LICENSE','LICENSING.md')) { Copy-Item -LiteralPath (Join-Path $root $notice) -Destination $out }
Copy-Item -LiteralPath (Join-Path $root 'docs/CORE-DISTRIBUTION.md') -Destination (Join-Path $out 'CORE-DISTRIBUTION.md')
New-Item -ItemType Directory -Force (Join-Path $out 'licenses/model-evidence') | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'docs/license-evidence/crt-tv.json') -Destination (Join-Path $out 'licenses/model-evidence/crt-tv.json')
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
    foreach ($name in @('table_ao.png','floor_ao.png','table_contact_albedo.res','bake.json')) {
        Copy-Item -LiteralPath (Join-Path $roomBake $name) -Destination $bakeOut
    }
    Copy-Item -LiteralPath (Join-Path $root 'docs/room-contact-bake.md') -Destination (Join-Path $out 'assets/ROOM-CONTACT-BAKE.md')
}
# Linux shebangs must stay LF even when the checkout uses Windows line endings.
foreach ($name in @('crt-xr.x86_64','launch-deck.sh','launch-steam.sh','launch-glasses.sh','steam-session.py','tracking-session.py','display-probe.py','glasses-session.py','driver-sbs.py')) {
    $scriptPath = Join-Path $out $name
    $text = [IO.File]::ReadAllText($scriptPath).Replace("`r`n", "`n")
    [IO.File]::WriteAllText($scriptPath, $text, [Text.UTF8Encoding]::new($false))
}
$installerOut = Join-Path $out 'installer'
New-Item -ItemType Directory -Force $installerOut | Out-Null
foreach ($name in @('install.py','steam_config.py')) {
    $text = [IO.File]::ReadAllText((Join-Path $root "scripts/installer/$name")).Replace("`r`n", "`n")
    [IO.File]::WriteAllText((Join-Path $installerOut $name), $text, [Text.UTF8Encoding]::new($false))
}
$text = [IO.File]::ReadAllText((Join-Path $root 'scripts/installer/Install-CRT-XR.sh')).Replace("`r`n", "`n")
[IO.File]::WriteAllText((Join-Path $out 'Install-CRT-XR.sh'), $text, [Text.UTF8Encoding]::new($false))
foreach ($name in @('GETTING-STARTED.md','PRE-LAUNCH-CHECKLIST.md','LICENCE-PROPOSAL.md')) {
    Copy-Item -LiteralPath (Join-Path $root "docs/$name") -Destination $out
}
$artworkOut = Join-Path $out 'artwork'
New-Item -ItemType Directory -Force $artworkOut | Out-Null
foreach ($name in @('Portrait.png','Landscape.png','Hero.png','Logo.png','Icon.png')) {
    Copy-Item -LiteralPath (Join-Path $root "artwork/$name") -Destination $artworkOut
}
Write-Host "Linux package: $out"

$text = [IO.File]::ReadAllText((Join-Path $root 'scripts/installer/Install CRT XR.desktop')).Replace("`r`n", "`n")
[IO.File]::WriteAllText((Join-Path $out 'Install CRT XR.desktop'), $text, [Text.UTF8Encoding]::new($false))
