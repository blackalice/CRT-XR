"""Summarise a live play trace (scripts/diagnostics/live_trace.gd) per game.

Only time actually playing counts: a game loaded, not paused, no menu, no loading
card. Reports room frame pacing, the TV picture's cadence (room frames that
repeated the previous game frame, game frames replaced before they were shown),
emulator step spikes, audio dropouts and picture age, plus the worst moments
as minutes into the session.

usage: python analyze-play-trace.py <trace.jsonl> [more traces...]
"""
import json
import statistics
import sys
from collections import defaultdict


def pct(values, p):
    if not values:
        return 0.0
    values = sorted(values)
    return values[min(len(values) - 1, int(len(values) * p))]


def load(path):
    events = []
    with open(path, encoding='utf-8') as source:
        for line in source:
            line = line.strip()
            if line:
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    pass  # a line cut short when the app was closed
    return sorted(events, key=lambda e: e.get('t', 0))


def summarise(path):
    events = load(path)
    if not events:
        print(path, ': empty')
        return
    start = events[0]['t']
    context = {}
    games = defaultdict(lambda: {'ticks': [], 'draws': [], 'emu': [], 'time': 0.0, 'target': 60.0, 'system': '', 'refresh': set()})
    last_t = None
    for e in events:
        kind = e.get('k')
        if kind == 'start':
            print(f"{path}\n  refresh {e.get('refresh')} Hz, window {e.get('window')}, build {e.get('version')}")
            continue
        if kind == 'context':
            context = e
            continue
        playing = context.get('game') and not context.get('paused') and not context.get('menu') and not context.get('card')
        if not playing:
            continue
        g = games[context['game']]
        g['system'] = context.get('system', '')
        g['target'] = context.get('target_fps') or g['target']
        # The launch-time rate in 'start' can predate the glasses' SBS mode.
        if context.get('refresh'): g['refresh'].add(round(context['refresh'], 2))
        if kind == 'tick':
            g['ticks'].append((e['t'], e['gap']))
        elif kind == 'draw':
            g['draws'].append((e['t'], e['gap']))
        elif kind == 'emu':
            g['emu'].append(e)
    for name, g in games.items():
        ticks = [gap / 1000 for _, gap in g['ticks'] if gap < 1_000_000]
        if len(ticks) < 120:
            continue
        seconds = sum(ticks) / 1000
        room_hz = len(ticks) / seconds
        draws = [gap / 1000 for _, gap in g['draws'] if gap < 1_000_000]
        emu = g['emu']
        steps = [s / 1000 for e in emu for s in e.get('steps', [])]
        shown = [bool(e.get('shown')) for e in emu]
        repeats = shown.count(False)
        dropped = (max(e.get('dropped', 0) for e in emu) - min(e.get('dropped', 0) for e in emu)) if emu else 0
        ages = [a / 1000 for e in emu for a in e.get('ages', [])]
        recov = (max(e.get('recoveries', 0) for e in emu) - min(e.get('recoveries', 0) for e in emu)) if emu else 0
        emu_fps = len(steps) / seconds if seconds else 0
        expected_repeats = max(0.0, room_hz - g['target']) * seconds
        # Irregular cadence: a room frame without a new picture next to one where
        # a game frame was replaced unseen (the pair the eye reads as a stutter).
        drops_at = []
        previous = None
        for e in emu:
            d = e.get('dropped', 0)
            if previous is not None and d > previous:
                drops_at.append(e['t'])
            previous = d
        print(f"\n  {name}  [{g['system']}]  {seconds / 60:.1f} min playing"
              + (f"  (display {', '.join(f'{r:g}' for r in sorted(g['refresh']))} Hz)" if g['refresh'] else ""))
        print(f"    room   : {room_hz:.2f} Hz  frame ms p50/p95/p99/max {pct(ticks, .5):.1f}/{pct(ticks, .95):.1f}/{pct(ticks, .99):.1f}/{max(ticks):.1f}"
              f"  missed vsync (>20 ms) {sum(t > 20 for t in ticks)}  (>34 ms) {sum(t > 34 for t in ticks)}")
        if draws:
            print(f"    draws  : p99 {pct(draws, .99):.1f} ms  max {max(draws):.1f} ms")
        print(f"    game   : {emu_fps:.2f} emulated fps (target {g['target']:.2f})  step ms p50/p95/max {pct(steps, .5):.1f}/{pct(steps, .95):.1f}/{max(steps, default=0):.1f}"
              f"  >25 ms {sum(s > 25 for s in steps)}")
        per_min = 60 / seconds if seconds else 0
        print(f"    picture: repeated {repeats} room frames ({repeats * per_min:.1f}/min; rate mismatch alone ~{expected_repeats * per_min:.1f}/min)"
              f"  game frames dropped unseen {dropped} ({dropped * per_min:.1f}/min)")
        if ages:
            print(f"    age    : picture age ms p50/p95 {pct(ages, .5):.1f}/{pct(ages, .95):.1f}")
        print(f"    audio  : dropouts {recov}  queued ms p50 ~{statistics.median([e.get('queued', 0) for e in emu]) / 48:.0f} (48 kHz estimate)")
        worst = sorted(g['ticks'], key=lambda x: -x[1])[:5]
        moments = ', '.join(f"{(t - start) / 60e6:.1f} min ({gap / 1000:.0f} ms)" for t, gap in worst if gap > 25000)
        if moments:
            print(f"    longest room frames: {moments}")
        if drops_at:
            minutes = sorted({round((t - start) / 60e6, 1) for t in drops_at})
            print(f"    dropped-frame moments (min): {minutes[:20]}{' ...' if len(minutes) > 20 else ''}")


for argument in sys.argv[1:]:
    summarise(argument)
