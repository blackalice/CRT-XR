"""Read-only Gaming Mode display probe. Never selects modes or changes Steam settings."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import time


def dimensions(value):
    match = re.fullmatch(r"([0-9]{3,5})x([0-9]{3,5})", value)
    if not match:
        raise ValueError("Expected WIDTHxHEIGHT")
    size = tuple(map(int, match.groups()))
    if size[0] % 2 or not (640 <= size[0] <= 16384 and 480 <= size[1] <= 8192):
        raise ValueError("Unsupported SBS dimensions")
    return size


# Glasses name their maker in the display's EDID. VITURE is confirmed on
# hardware; the other brands' names still need confirming with their glasses.
# A resolution test would also match 32:9 desktop monitors, so names decide.
GLASSES_NAMES = (b'viture', b'xreal', b'nreal', b'rokid', b'rayneo')


def is_glasses_edid(edid):
    lowered = edid.lower()
    return any(name in lowered for name in GLASSES_NAMES)


def inventory(root=Path('/sys/class/drm')):
    outputs = []
    for status in sorted(root.glob('card*-*/status')):
        try:
            if status.read_text().strip() != 'connected':
                continue
            edid = status.with_name('edid').read_bytes()
            modes = status.with_name('modes').read_text().splitlines()
            outputs.append(dict(connector=status.parent.name, edid_sha256=hashlib.sha256(edid).hexdigest() if edid else '',
                                known_glasses=is_glasses_edid(edid), advertised_modes=list(dict.fromkeys(modes)),
                                active_mode=None))
        except OSError:
            continue # Hotplug may remove files between reads; retry on the next poll.
    return outputs


def report(target, root=Path('/sys/class/drm'), connector=''):
    outputs = inventory(root)
    candidates = [o for o in outputs if (o['connector'] == connector if connector else o['known_glasses'])]
    selected = candidates[0] if len(candidates) == 1 else None
    return dict(schema=1, timestamp=time.time(), expected=list(target), outputs=outputs,
                selected_connector=selected['connector'] if selected else '',
                advertised=bool(selected and '%dx%d' % target in selected['advertised_modes']),
                physical_mode_verified=False)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--size', default='3840x1080', type=dimensions)
    parser.add_argument('--connector', default='')
    args=parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    previous=None
    while True:
        data=report(args.size, connector=args.connector)
        temporary=args.output.with_suffix('.tmp')
        temporary.write_text(json.dumps(data), encoding='utf-8'); temporary.replace(args.output)
        signature=json.dumps([data['outputs'], data['selected_connector'], data['advertised']])
        if signature != previous:
            with args.output.with_suffix('.jsonl').open('a', encoding='utf-8') as log: log.write(json.dumps(data)+'\n')
            previous=signature
        time.sleep(.5)

if __name__=='__main__': main()
