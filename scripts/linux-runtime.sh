#!/usr/bin/env bash
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Keep libstdc++ alive for the whole process. On SteamOS, unloading/reloading
# C++ cores can otherwise leave stale locale facets when returning to Snes9x.
# Scope this to RetroCRT and retain the user's other preload libraries.
export LD_PRELOAD="libstdc++.so.6${LD_PRELOAD:+:$LD_PRELOAD}"
exec "$here/retrocrt-engine.x86_64" --main-pack "$here/retrocrt.pck" "$@"
