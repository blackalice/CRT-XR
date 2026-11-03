"""Attribute frame gaps to measured emulation work, including catch-up frames."""
import bisect
import json
from pathlib import Path
import statistics
import sys

events = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
ticks = sorted((e for e in events if e['kind'] == 'tick'), key=lambda e: e['at_us'])
work = sorted((e for e in events if e['kind'] == 'emulation'), key=lambda e: e['at_us'])
starts = [e['at_us'] for e in work]
rows = []
for previous, current in zip(ticks, ticks[1:]):
    if not current['phase'].startswith('play:') or previous['phase'] != current['phase']:
        continue
    begin, end = previous['at_us'], current['at_us']
    batch = work[bisect.bisect_left(starts, begin):bisect.bisect_left(starts, end)]
    steps = [step for e in batch for step in e['steps']]
    process = sum(e['process_us'] for e in batch)
    rows.append({
        'at_s': round(end / 1e6, 3), 'phase': current['phase'],
        'wall_ms': round((end-begin)/1000, 2),
        'emulation_ms': round(process/1000, 2),
        'core_ms': round(sum(s['core_us'] for s in steps)/1000, 2),
        'readback_ms': round(sum(s['readback_us'] for s in steps)/1000, 2),
        'max_step_ms': round(max((s['core_us'] for s in steps), default=0)/1000, 2),
        'present_ms': round(sum(e['present_us'] for e in batch)/1000, 2),
        'outside_emulation_ms': round(((end-begin)-process)/1000, 2),
        'steps': len(steps),
    })
print(json.dumps({
    'execution_mode': 'async' if any(e.get('mode') == 'async' for e in work) else 'sync',
    'native_timing': 'worker results collected in interval' if any(e.get('mode') == 'async' for e in work) else 'work blocking interval',
    'play_frames': len(rows),
    'median_ms': round(statistics.median(r['wall_ms'] for r in rows), 2) if rows else None,
    'over_50ms': sum(r['wall_ms'] > 50 for r in rows),
    'worst_draw_ms': round(max((e['gap_us'] for e in events
                               if e['kind'] == 'draw' and e['phase'].startswith('play:')), default=0)/1000, 2),
    'worst': sorted(rows, key=lambda r: r['wall_ms'], reverse=True)[:15],
}, indent=2))
