"""Generate the chiptune sound effects for the table modes.

Square and triangle waves only, so they sit with the pixel art. Run from the repo
root:  python3 tools/make_mode_sfx.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT_DIR = Path("Audio/sfx")


def square(freq, t):
    return 1.0 if (freq * t) % 1.0 < 0.5 else -1.0


def triangle(freq, t):
    p = (freq * t) % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def notes(seq, wave_fn=square, volume=0.28):
    """seq: list of (frequency, seconds). A short decay on each note keeps it plucky."""
    out = []
    for freq, dur in seq:
        n = int(RATE * dur)
        for i in range(n):
            t = i / RATE
            env = min(1.0, i / 60) * (1.0 - i / n) ** 0.6
            out.append(wave_fn(freq, t) * env * volume if freq else 0.0)
    return out


def sweep(f0, f1, dur, wave_fn=triangle, volume=0.32, vibrato=0.0):
    out, phase = [], 0.0
    n = int(RATE * dur)
    for i in range(n):
        k = i / n
        freq = f0 + (f1 - f0) * k
        freq *= 1.0 + vibrato * math.sin(2 * math.pi * 18 * i / RATE)
        phase += freq / RATE
        env = min(1.0, i / 60) * (1.0 - k) ** 0.8
        out.append(wave_fn(1.0, phase) * env * volume)
    return out


def mixdown(*parts):
    """Plays several sounds over each other."""
    out = [0.0] * max(len(p) for p in parts)
    for part in parts:
        for i, s in enumerate(part):
            out[i] += s
    return out


def write(name, samples):
    with wave.open(str(OUT_DIR / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0


def main():
    write("ramp.wav", notes([(C5, 0.05), (E5, 0.05), (G5, 0.05), (C6, 0.12)]))
    write("kickback.wav", sweep(180, 900, 0.22))
    write("charge.wav", notes([(G5, 0.06), (C6, 0.06), (G5, 0.06), (C6, 0.16)], triangle, 0.4))
    write("spirit.wav", sweep(300, 1200, 0.45, triangle, 0.35, vibrato=0.04))
    write("spirit_hit.wav", sweep(1400, 500, 0.09, square, 0.22))
    write("catch.wav", notes([(C5, 0.08), (E5, 0.08), (G5, 0.08), (C6, 0.08), (0, 0.04), (G5, 0.08), (C6, 0.3)]))
    write("spinner.wav", notes([(G6, 0.02)], square, 0.16))
    write("upgrade.wav", notes([(C5, 0.05), (G5, 0.05), (C6, 0.05), (E6, 0.05), (G6, 0.22)], triangle, 0.4))
    write("downgrade.wav", sweep(700, 260, 0.3, triangle, 0.3))
    # a frog's croak with a plop of water under it, for the frog bumpers
    write("frog.wav", mixdown(sweep(420, 180, 0.09, square, 0.2, vibrato=0.08), notes([(0, 0.02), (C6, 0.03)], triangle, 0.2)))
    # a torch catching: a rising rush of flame
    write("torch.wav", sweep(200, 700, 0.18, square, 0.14, vibrato=0.3))
    # the shrine swallowing the ball: a low gong that sinks, then rises when it spits it out
    write("shrine.wav", sweep(220, 90, 0.5, triangle, 0.45, vibrato=0.02))
    write("shrine_out.wav", sweep(120, 520, 0.2, triangle, 0.4))
    # stone on stone, and water poured into the Chac Mool's bowl
    write("chac_mool.wav", mixdown(notes([(98.0, 0.05)], square, 0.3), notes([(0, 0.03), (G5, 0.04), (C6, 0.08)], triangle, 0.25)))
    write("multiball.wav", notes([(G5, 0.07), (0, 0.02), (G5, 0.07), (0, 0.02), (C6, 0.07), (E6, 0.07), (G6, 0.25)]))
    print("wrote mode sound effects")


if __name__ == "__main__":
    main()
