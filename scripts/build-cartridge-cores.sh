#!/usr/bin/env bash
# Compatibility entry point. The release builder handles all three cores and records provenance.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$root/scripts/build-release-cores.py" "${1:-all}"
