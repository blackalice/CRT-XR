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
