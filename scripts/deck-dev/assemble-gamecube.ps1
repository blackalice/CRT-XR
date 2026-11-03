param([string]$Out = 'dist/deck-gamecube-20261103b')
$ErrorActionPreference = 'Stop'
Set-Location D:\git\XR-CRT
./scripts/export-linux.ps1 -OutputDirectory $Out | Out-Null
Copy-Item cores/dolphin_libretro.so,cores/dolphin-test-build.json,cores/Dolphin-LICENSE.txt "$Out/cores/" -Force
Copy-Item cores/Dolphin-LICENSES "$Out/cores/" -Recurse -Force
New-Item -ItemType Directory -Force "$Out/core-data" | Out-Null
Copy-Item core-data/dolphin-emu "$Out/core-data/" -Recurse -Force
$p = "$Out/crt-xr.x86_64"; $t = [IO.File]::ReadAllText($p)
if ($t -notmatch 'EXPERIMENTAL_GAMECUBE') {
  $t = $t.Replace("set -euo pipefail`n", "set -euo pipefail`n# Experimental GameCube (Dolphin) support is on in this build.`nexport CRT_XR_EXPERIMENTAL_GAMECUBE=1`n")
  [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
}
"lib: " + (Get-FileHash extensions/bin/crt_xr_libretro.linux.x86_64.so).Hash.Substring(0,12) + " / " + (Get-FileHash "$Out/crt_xr_libretro.linux.x86_64.so").Hash.Substring(0,12)
