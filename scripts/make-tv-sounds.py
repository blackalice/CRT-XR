"""Synthesises the TV and room sounds into assets/audio/tv/.

Original, procedurally generated sounds (CC0-1.0, like the VCR sounds): a channel
change, a degauss, the power-off, and quiet room ambience. No recordings.
Deterministic: the same script always writes the same files.

    python scripts/make-tv-sounds.py
"""
from pathlib import Path
import wave
import numpy as np

RATE = 48000
OUT = Path(__file__).resolve().parent.parent / "assets/audio/tv"
rng = np.random.default_rng(1983)


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


def band(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    return one_pole(one_pole(signal, low, high=True), high)


def decay(length: int, tau: float) -> np.ndarray:
    return np.exp(-np.arange(length) / (tau * RATE))


def ring(freq: float, tau: float, length: int) -> np.ndarray:
    t = np.arange(length) / RATE
    return np.sin(2 * np.pi * freq * t) * decay(length, tau)


def tick(length: int, at: float, gain: float, pitch: float) -> np.ndarray:
    """A sharp mechanical tick: a filtered click and a short ring."""
    out = np.zeros(length)
    burst = one_pole(rng.standard_normal(seconds(0.003)), 1500, high=True) * decay(seconds(0.003), 0.0005)
    burst += ring(pitch, 0.003, len(burst)) * 0.7
    start = seconds(at)
    end = min(length, start + len(burst))
    out[start:end] += burst[: end - start] * gain
    return out


def seamless(make, length_s: float, fade_s: float = 0.5) -> np.ndarray:
    """A loop with no seam: the tail is crossfaded into the head."""
    length, fade = seconds(length_s), seconds(fade_s)
    sound = make(length + fade)
    ramp = np.linspace(0.0, 1.0, fade)
    head = sound[:length].copy()
    head[:fade] = sound[:fade] * ramp + sound[length:length + fade] * (1.0 - ramp)
    return head


def normalise(sound: np.ndarray, peak: float) -> np.ndarray:
    return sound / max(np.abs(sound).max(), 1e-9) * peak


def faded(sound: np.ndarray, tail_s: float = 0.03) -> np.ndarray:
    """One-shots end on silence, without a click."""
    tail = seconds(tail_s)
    sound = sound.copy()
    sound[-tail:] *= np.linspace(1.0, 0.0, tail)
    return sound


def write(name: str, sound: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(sound, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(OUT / name), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())


def channel() -> np.ndarray:
    """Changing input: a relay click, then a burst of static that settles."""
    length = seconds(0.5)
    hiss = band(rng.standard_normal(length), 300, 7000)
    envelope = np.minimum(np.arange(length) / seconds(0.01), 1.0) * decay(length, 0.16)
    sound = hiss * envelope * 0.8
    sound += tick(length, 0.0, 1.6, 2400) + tick(length, 0.012, 0.8, 1700)
    return normalise(sound, 0.55)


def degauss() -> np.ndarray:
    """The coil: a deep thunk, then a buzzing hum that dies away."""
    length = seconds(1.8)
    t = np.arange(length) / RATE
    thunk = ring(62, 0.18, length) + ring(124, 0.09, length) * 0.5
    # The coil's mains buzz: odd harmonics of 60 Hz, fading over a second.
    buzz = sum(np.sin(2 * np.pi * 60 * k * t) / k for k in (1, 3, 5, 7, 9))
    buzz *= np.minimum(t / 0.03, 1.0) * np.exp(-t / 0.55) * 0.35
    rattle = band(rng.standard_normal(length), 800, 4000) * np.exp(-t / 0.08) * 0.25
    sound = thunk + buzz + rattle + tick(length, 0.0, 1.2, 1200)
    return normalise(sound, 0.6)


def power_off() -> np.ndarray:
    """Switching off: a click, a soft thump, then the tube's fading crackle."""
    length = seconds(0.9)
    t = np.arange(length) / RATE
    sound = tick(length, 0.0, 1.5, 2000)
    sound += ring(80, 0.06, length) * 0.6
    # A falling whistle from the collapsing deflection.
    whistle = np.sin(2 * np.pi * np.cumsum(np.linspace(9000, 3000, length)) / RATE)
    sound += whistle * np.exp(-t / 0.12) * 0.08
    for i in range(40):
        at = rng.uniform(0.02, 0.85) ** 1.8
        sound += tick(length, at, rng.uniform(0.15, 0.5) * (1.0 - at), rng.uniform(2500, 6000))
    return normalise(sound, 0.5)


def room_tone(length: int) -> np.ndarray:
    """A quiet room: low, soft air with a slow, gentle movement."""
    brown = np.cumsum(rng.standard_normal(length))
    brown -= one_pole(brown, 2.0)  # remove the drift, keep the rumble
    air = one_pole(brown, 220) + band(rng.standard_normal(length), 200, 1200) * 0.02
    swell = 0.8 + 0.2 * np.sin(2 * np.pi * np.arange(length) / RATE / 7.3)
    return air * swell


def rain(length: int) -> np.ndarray:
    """Rain on the window: a soft wash with drops, heard from indoors."""
    t = np.arange(length) / RATE
    gust = one_pole(rng.standard_normal(length), 0.4)
    gust = 0.75 + 0.25 * gust / max(np.abs(gust).max(), 1e-9)
    wash = band(rng.standard_normal(length), 500, 3500) * gust * 0.5
    drops = np.zeros(length)
    for at in np.sort(rng.uniform(0.0, t[-1], int(t[-1] * 55))):
        drops += tick(length, at, rng.uniform(0.05, 0.4) ** 1.5, rng.uniform(1800, 4200))
    sound = wash + one_pole(drops, 3000)
    return sound + room_tone(length) * 0.3


def clock_tick(pitch: float) -> np.ndarray:
    length = seconds(0.06)
    return normalise(tick(length, 0.0, 1.0, pitch) + tick(length, 0.004, 0.4, pitch * 1.8), 0.35)


def whine() -> np.ndarray:
    """The flyback transformer at the NTSC line rate (15,734 Hz). One second
    holds a whole number of cycles, so it loops without a seam."""
    t = np.arange(RATE) / RATE
    return np.sin(2 * np.pi * 15734 * t) * 0.25


def main() -> None:
    write("channel.wav", faded(channel()))
    write("degauss.wav", faded(degauss()))
    write("power-off.wav", faded(power_off()))
    write("ambience-room.wav", normalise(seamless(room_tone, 10.0), 0.4))
    write("ambience-rain.wav", normalise(seamless(rain, 14.0), 0.5))
    write("clock-tick.wav", clock_tick(3200))
    write("clock-tock.wav", clock_tick(2500))
    write("crt-whine.wav", whine())
    print("Wrote TV and room sounds to", OUT)


if __name__ == "__main__":
    main()
