"""Synthesises the VCR prop's mechanism sounds into assets/audio/vcr/.

Original, procedurally generated sounds (CC0-1.0, like the test generators):
solenoid clicks, mechanism thunks and a motor, coloured by the ringing of a
plastic cabinet. Deterministic: the same script always writes the same files.

    python scripts/make-vcr-sounds.py
"""
from pathlib import Path
import wave
import numpy as np

RATE = 48000
OUT = Path(__file__).resolve().parent.parent / "assets/audio/vcr"
rng = np.random.default_rng(1987)


def seconds(n: float) -> int:
    return int(round(n * RATE))


def one_pole(signal: np.ndarray, cutoff: float, high: bool = False) -> np.ndarray:
    """First-order low-pass (or the matching high-pass) at `cutoff` Hz."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    state = 0.0
    for i, x in enumerate(signal):
        state = (1.0 - a) * x + a * state
        out[i] = state
    return signal - out if high else out


def decay(length: int, tau: float) -> np.ndarray:
    return np.exp(-np.arange(length) / (tau * RATE))


def ring(freq: float, tau: float, length: int) -> np.ndarray:
    t = np.arange(length) / RATE
    return np.sin(2 * np.pi * freq * t) * decay(length, tau)


# The cabinet: a few plastic modes, each struck by every impact.
BODY = sum(ring(f, tau, seconds(0.12)) * g for f, tau, g in
           [(185, 0.030, 0.6), (430, 0.020, 0.8), (960, 0.012, 0.7), (2150, 0.006, 0.5), (3900, 0.003, 0.3)])
BODY /= np.abs(BODY).sum() * 0.05


def through_body(signal: np.ndarray) -> np.ndarray:
    return np.convolve(signal, BODY)[: len(signal)] * 0.5 + signal * 0.5


def click(length: int, at: float, gain: float) -> np.ndarray:
    """A solenoid or lever: a sharp, bright tick."""
    out = np.zeros(length)
    burst = one_pole(rng.standard_normal(seconds(0.004)), 1800, high=True) * decay(seconds(0.004), 0.0006)
    burst += ring(2800 + rng.uniform(-200, 200), 0.004, len(burst)) * 0.6
    start = seconds(at)
    out[start:start + len(burst)] += burst * gain
    return out


def thunk(length: int, at: float, gain: float, pitch: float = 95.0) -> np.ndarray:
    """A heavier mechanism landing: a falling low knock with a dull rattle."""
    out = np.zeros(length)
    n = seconds(0.18)
    t = np.arange(n) / RATE
    falling = pitch * (1.0 + 0.6 * np.exp(-t / 0.01))
    knock = np.sin(2 * np.pi * np.cumsum(falling) / RATE) * decay(n, 0.035)
    rattle = one_pole(rng.standard_normal(n), 900) * decay(n, 0.02) * 1.6
    start = seconds(at)
    out[start:start + n] += (knock + rattle) * gain
    return out


def motor(length: int, start: float, end: float, gain: float, f0: float = 118.0, rise: float = 0.25, fall: float = 0.2) -> np.ndarray:
    """The capstan and drum motor: a soft hum with a faint whine, ramping in and out."""
    t = np.arange(length) / RATE
    env = np.clip((t - start) / rise, 0, 1) * np.clip((end - t) / fall, 0, 1)
    speed = 0.6 + 0.4 * env  # spins up as it powers on
    phase = 2 * np.pi * np.cumsum(f0 * speed) / RATE
    hum = sum(np.sin(phase * k) / k for k in range(1, 6))
    whine = np.sin(phase * 9.5) * 0.15
    return (hum + whine) * env * gain


def finish(name: str, signal: np.ndarray, body: bool = True) -> None:
    if body: signal = through_body(signal)
    signal = one_pole(signal, 30, high=True)  # no DC thump through small speakers
    signal *= 0.7 / max(1e-6, np.abs(signal).max())
    fade = min(len(signal), seconds(0.01))
    signal[-fade:] *= np.linspace(1, 0, fade)
    write(name, signal)


def write(name: str, signal: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(data)
    print(name, f"{len(signal) / RATE:.2f} s")


def search_loop() -> np.ndarray:
    """FF/REW: the reels and motor at full speed, with tape hiss. Every tone
    completes whole cycles in the loop, and the noise is cross-faded, so it
    repeats without a seam."""
    length = seconds(1.0)
    t = np.arange(length) / RATE
    flutter = 1.0 + 0.004 * np.sin(2 * np.pi * 6 * t)
    f0 = 236.0  # whole cycles per second, so the loop joins cleanly
    phase = 2 * np.pi * f0 * t
    whir = sum(np.sin(phase * k) / k ** 1.2 for k in range(1, 7)) * flutter
    whine = np.sin(2 * np.pi * 1416.0 * t) * 0.18 + np.sin(2 * np.pi * 2832.0 * t) * 0.06
    flap = 0.65 + 0.35 * np.sin(2 * np.pi * 9 * t) ** 2  # the reels' tape catching
    hiss = one_pole(one_pole(rng.standard_normal(length * 2), 6000), 700, high=True)
    hiss = hiss[:length] * np.linspace(1, 0, length) + hiss[length:] * np.linspace(0, 1, length)
    loop = (whir * 0.55 + whine) * flap + hiss * 0.35
    return loop * 0.6 / np.abs(loop).max()


def main() -> None:
    n = seconds(1.1)  # play: lever, cassette drawn in and laced, motor running
    finish("vcr-play.wav", click(n, 0.0, 0.8) + thunk(n, 0.12, 0.9, 88) + click(n, 0.42, 0.5)
           + thunk(n, 0.55, 0.6, 120) + motor(n, 0.1, 1.08, 0.05))
    n = seconds(0.3)  # resume: the pinch roller closing
    finish("vcr-resume.wav", click(n, 0.0, 0.7) + thunk(n, 0.04, 0.45, 130))
    n = seconds(0.25)  # pause: a lighter tick
    finish("vcr-pause.wav", click(n, 0.0, 0.9) + thunk(n, 0.015, 0.25, 150))
    n = seconds(0.7)  # stop: mechanism releasing as the motor winds down
    finish("vcr-stop.wav", click(n, 0.0, 0.6) + thunk(n, 0.05, 1.0, 80) + motor(n, -0.1, 0.6, 0.05, rise=0.01, fall=0.5))
    write("vcr-search.wav", search_loop())


if __name__ == "__main__":
    main()
