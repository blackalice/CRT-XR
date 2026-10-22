$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
function Fetch-Pinned([string]$Name, [string]$Repository, [string]$Commit) {
    $path = Join-Path $root "tools/$Name"
    if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) {
        git clone $Repository $path
        if ($LASTEXITCODE -ne 0) { throw "Clone failed: $Name" }
    }
    $current = git -C $path rev-parse HEAD
    if ($current -ne $Commit) {
        if (git -C $path status --porcelain) { throw "Local edits in $Name; refusing to change checkout." }
        git -C $path checkout --detach $Commit
        if ($LASTEXITCODE -ne 0) { throw "Cannot select pinned source: $Name" }
    }
}
Fetch-Pinned 'godot-cpp' 'https://github.com/godotengine/godot-cpp.git' 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77'
Fetch-Pinned 'snes9x' 'https://github.com/snes9xgit/snes9x.git' '1bcc369e89f08243e0a462882fb1f3e42e51de3a'
Fetch-Pinned 'nestopia' 'https://github.com/libretro/nestopia.git' '06a8949e0b3cf60e3a38a374b1426bf40fccb9a0'
Fetch-Pinned 'genesis-plus-gx' 'https://github.com/libretro/Genesis-Plus-GX.git' '393f70cd64c7334564c19a424c383f53986c13f4'
Fetch-Pinned 'gambatte' 'https://github.com/libretro/gambatte-libretro.git' 'd9d6cd06382d1ced30de34d56d3609452323dab1'
Fetch-Pinned 'mgba' 'https://github.com/libretro/mgba.git' '7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6'
Fetch-Pinned 'beetle-pce-fast' 'https://github.com/libretro/beetle-pce-fast-libretro.git' '3f946f277aef3aa99a95551618bbcd1dd2bda0d9'
Fetch-Pinned 'beetle-lynx' 'https://github.com/libretro/beetle-lynx-libretro.git' 'fcdefcfb3c11d6d2e71be076a5d3df2e88ab73ed'
Fetch-Pinned 'beetle-ngp' 'https://github.com/libretro/beetle-ngp-libretro.git' 'a50d5ac288a81f2104ddf43195a4efdd15c72227'
Fetch-Pinned 'stella' 'https://github.com/libretro/stella.git' 'ba52c43b9eda950eb0c0eec69cda9b17dee8c39b'
Fetch-Pinned 'vecx' 'https://github.com/libretro/libretro-vecx.git' 'dccff5402a16d1ea7c112095a8e42632bf149506'
