#!/usr/bin/env bash
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"
if [[ ! -x ./crt-xr.x86_64 ]]; then
    echo 'Missing executable or execute permission. Run chmod +x crt-xr.x86_64' >&2
    exit 1
fi
# OpenGL compatibility avoids the Breezy Vulkan layer. This does not disable
# Gamescope/ReShade compositing; check XR Gaming presentation settings on Deck.
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/crt_xr"
exec ./crt-xr.x86_64 --rendering-method gl_compatibility \
    --log-file "${XDG_STATE_HOME:-$HOME/.local/state}/crt_xr/godot.log" "$@"
