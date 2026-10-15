# Official builds, pinned by archive SHA-256. Run setup-emulation.ps1 first.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content -LiteralPath (Join-Path $root 'third_party/cores/builds.json') -Raw | ConvertFrom-Json
$downloads = Join-Path $root 'build/multicore-downloads'
New-Item -ItemType Directory -Force $downloads, (Join-Path $root 'cores/sources') | Out-Null
foreach ($build in $manifest.builds) {
    $archive = Join-Path $downloads "$($build.core)-$($build.platform).zip"
    if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest $build.url -OutFile $archive }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $build.sha256) {
        throw "Core archive changed: $archive. Refusing unverified download; use build-cartridge-cores.sh or review and update the manifest."
    }
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $root 'cores') -Force
}
foreach ($pair in @(@('nestopia','06a8949e0b3cf60e3a38a374b1426bf40fccb9a0'), @('genesis-plus-gx','393f70cd64c7334564c19a424c383f53986c13f4'))) {
    $source = Join-Path $root "tools/$($pair[0])"
    if ((git -C $source rev-parse HEAD) -ne $pair[1]) { throw 'Core source revision mismatch; run setup-emulation.ps1.' }
    git -C $source archive --format=tar.gz "--prefix=$($pair[0])/" "--output=$root/cores/sources/$($pair[0])-$($pair[1]).tar.gz" HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not archive core source.' }
}
Copy-Item -LiteralPath (Join-Path $root 'tools/nestopia/COPYING') -Destination (Join-Path $root 'cores/Nestopia-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $root 'tools/genesis-plus-gx/LICENSE.txt') -Destination (Join-Path $root 'cores/Genesis-Plus-GX-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $root 'third_party/cores/builds.json') -Destination (Join-Path $root 'cores/core-builds.json')
