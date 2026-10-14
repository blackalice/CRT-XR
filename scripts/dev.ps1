param([switch]$Editor, [switch]$Stereo, [switch]$Test, [switch]$EmulationTest, [switch]$GamepadTest, [string]$Rom)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $root 'tools/godot/Godot_v4.5.1-stable_win64_console.exe'
if ($env:GODOT_BIN) { $godot = $env:GODOT_BIN }
if (-not (Test-Path -LiteralPath $godot)) { throw 'Run scripts/setup-windows.ps1 or set GODOT_BIN to Godot 4.5.1.' }
# Keep development logs and editor state within the workspace.
$env:APPDATA = Join-Path $root 'tools/userdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
if ($Test) {
    & $godot --headless --path $root --editor --import
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot --headless --path $root --script res://tests/smoke.gd
} elseif ($EmulationTest) {
    & $godot --headless --path $root --script res://tests/emulation.gd
} elseif ($GamepadTest) {
    & $godot --headless --path $root --quit-after 1200 --script res://tests/gamepad.gd
} elseif ($Editor) { & $godot --path $root --editor
} elseif ($Rom) {
    $romPath = (Resolve-Path -LiteralPath $Rom).Path
    if ($Stereo) { & $godot --path $root -- --sbs --rom $romPath }
    else { & $godot --path $root -- --rom $romPath }
} elseif ($Stereo) { & $godot --path $root -- --sbs
} else { & $godot --path $root }
exit $LASTEXITCODE
