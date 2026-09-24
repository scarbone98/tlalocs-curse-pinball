"""Compose the mode music: Audio/music/curse.ogg, spirit.ogg and el_dorado.ogg.

Pokemon Pinball changes music for Catch 'Em mode, Evolution and each bonus stage.
These are chiptune loops in the same voice as the sound effects (square, triangle
and noise channels), written as note lists below:

  curse       Tlaloc's Storm: D minor, 150 bpm, a driving bass and rain on the hats
  spirit      Ajolote: F major, 128 bpm, bouncy and bright for the spirit catch
  el_dorado   The Gilded King: A minor, 140 bpm, a fanfare for the bonus stage

Each track is one section played twice, the second time with a harmony line under
the lead, and loops seamlessly. Needs ffmpeg for the OGG encode.

Run from the repo root:  python3 tools/make_mode_music.py
"""
import math
import random
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

RATE = 22050
OUT_DIR = Path("Audio/music")
NOTE_NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(note):
    """'A4' -> 440.0; '-' is a rest."""
    if note == "-":
        return 0.0
    name, octave = note[:-1], int(note[-1])
    midi = 12 * (octave + 1) + NOTE_NAMES[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- voices -------------------------------------------------------------------------

def pulse(duty):
    return lambda phase: 1.0 if phase % 1.0 < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def render_line(notes, step_seconds, total_steps, voice, volume, attack=0.004, release=0.03,
                sustain=0.75, decay=0.08, vibrato=0.0):
    """notes: list of (note, steps). Renders into a buffer total_steps long."""
    out = [0.0] * int(total_steps * step_seconds * RATE)
    at = 0
    for note, steps in notes:
        f = freq(note)
        start = int(at * step_seconds * RATE)
        length = int(steps * step_seconds * RATE)
        if f:
            phase = 0.0
            for i in range(length):
                t = i / RATE
                env = min(1.0, t / attack)
                env *= sustain + (1 - sustain) * math.exp(-t / decay)
                env *= min(1.0, (length - i) / (release * RATE))
                vib = 1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.15)
                phase += f * vib / RATE
                if start + i < len(out):
                    out[start + i] += voice(phase) * env * volume
        at += steps
    return out


def render_drums(pattern, step_seconds, total_steps, volume, seed=1):
    """pattern: one char per step. k kick, s snare, h hat, c clap, . rest."""
    rng = random.Random(seed)
    out = [0.0] * int(total_steps * step_seconds * RATE)
    for step, hit in enumerate((pattern * (total_steps // len(pattern) + 1))[:total_steps]):
        start = int(step * step_seconds * RATE)
        if hit == "k":      # a thump that drops in pitch
            phase, n = 0.0, int(0.12 * RATE)
            for i in range(n):
                f = 140 * math.exp(-i / (0.03 * RATE)) + 45
                phase += f / RATE
                out[start + i] += math.sin(2 * math.pi * phase) * (1 - i / n) ** 2 * volume * 1.4
        elif hit in "sc":   # noise burst, longer for a snare
            n = int((0.14 if hit == "s" else 0.06) * RATE)
            for i in range(n):
                out[start + i] += rng.uniform(-1, 1) * (1 - i / n) ** 3 * volume * 0.9
        elif hit == "h":    # a tick of noise, like rain
            n = int(0.025 * RATE)
            for i in range(n):
                out[start + i] += rng.uniform(-1, 1) * (1 - i / n) ** 2 * volume * 0.35
    return out


def arpeggio(chords, steps_per_bar, octave_notes):
    """Sixteenth-note arpeggios up through each chord's notes."""
    notes = []
    for chord in chords:
        tones = octave_notes[chord]
        for i in range(steps_per_bar):
            notes.append((tones[i % len(tones)], 1))
    return notes


def bass_line(chords, pattern, roots):
    """pattern: per eighth note, 'r' root, 'o' root an octave up, 'f' fifth, '-' rest."""
    notes = []
    for chord in chords:
        root, octave_up, fifth = roots[chord]
        for p in pattern:
            notes.append(({"r": root, "o": octave_up, "f": fifth, "-": "-"}[p], 2))
    return notes


def harmony(lead, interval_down):
    """The lead again, a set number of semitones lower, for the second pass."""
    out = []
    for note, steps in lead:
        if note == "-":
            out.append((note, steps))
            continue
        name, octave = note[:-1], int(note[-1])
        midi = 12 * (octave + 1) + NOTE_NAMES[name] - interval_down
        names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        out.append((names[midi % 12] + str(midi // 12 - 1), steps))
    return out


def mix(tracks, gains):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for track, gain in zip(tracks, gains):
        for i, s in enumerate(track):
            out[i] += s * gain
    peak = max(abs(s) for s in out) or 1.0
    return [math.tanh(1.2 * s / peak) * 0.85 for s in out]   # gentle limiter


def write_ogg(name, samples):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4",
                        str(OUT_DIR / name)], check=True)


def song(bpm, chords, lead, bass_pattern, roots, arp_notes, drums, harmony_down, gains):
    """One section of len(chords) bars, then the same again with harmony under the lead."""
    step = 60.0 / bpm / 4
    bars = len(chords)
    steps = bars * 16
    lead_twice = lead + lead
    harmony_line = [("-", steps)] + harmony(lead, harmony_down)
    parts = [
        render_line(lead_twice, step, steps * 2, pulse(0.5), 0.55, vibrato=0.006),
        render_line(harmony_line, step, steps * 2, pulse(0.25), 0.35),
        render_line(bass_line(chords * 2, bass_pattern, roots), step, steps * 2, triangle, 0.9,
                    sustain=0.9, decay=0.2),
        render_line(arpeggio(chords * 2, 16, arp_notes), step, steps * 2, pulse(0.125), 0.22,
                    release=0.01, sustain=0.3, decay=0.03),
        render_drums(drums, step, steps * 2, 0.8),
    ]
    return mix(parts, gains)


def curse():
    chords = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"]
    lead = [
        ("D5", 4), ("F5", 2), ("A5", 2), ("G5", 4), ("F5", 2), ("E5", 2),
        ("D5", 6), ("A4", 2), ("D5", 4), ("-", 4),
        ("F5", 4), ("D5", 2), ("F5", 2), ("Bb5", 4), ("A5", 2), ("G5", 2),
        ("G5", 4), ("E5", 2), ("C5", 2), ("E5", 4), ("G5", 4),
        ("A5", 4), ("G5", 2), ("F5", 2), ("E5", 4), ("D5", 2), ("E5", 2),
        ("F5", 6), ("E5", 2), ("D5", 8),
        ("G5", 4), ("Bb5", 2), ("A5", 2), ("G5", 4), ("F5", 2), ("E5", 2),
        ("E5", 4), ("C#5", 2), ("E5", 2), ("A5", 8),
    ]
    roots = {"Dm": ("D2", "D3", "A2"), "Bb": ("Bb1", "Bb2", "F2"), "C": ("C2", "C3", "G2"),
             "Gm": ("G1", "G2", "D2"), "A": ("A1", "A2", "E2")}
    arp = {"Dm": ["D4", "F4", "A4", "D5"], "Bb": ["Bb3", "D4", "F4", "Bb4"], "C": ["C4", "E4", "G4", "C5"],
           "Gm": ["G3", "Bb3", "D4", "G4"], "A": ["A3", "C#4", "E4", "A4"]}
    return song(150, chords, lead, "roroforo", roots, arp, "khhhshhhkhkhshhh",
                harmony_down=3, gains=[1.0, 0.7, 1.0, 0.6, 0.9])


def spirit():
    chords = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C"]
    lead = [
        ("C5", 2), ("F5", 2), ("A5", 2), ("F5", 2), ("G5", 2), ("A5", 2), ("C6", 4),
        ("A5", 2), ("F5", 2), ("D5", 2), ("F5", 2), ("A5", 4), ("-", 4),
        ("D6", 2), ("C6", 2), ("Bb5", 2), ("A5", 2), ("G5", 4), ("F5", 4),
        ("E5", 2), ("G5", 2), ("C6", 2), ("G5", 2), ("E5", 4), ("C5", 4),
        ("F5", 2), ("A5", 2), ("C6", 2), ("A5", 2), ("F5", 4), ("C6", 4),
        ("E6", 2), ("C6", 2), ("A5", 2), ("C6", 2), ("E6", 4), ("-", 4),
        ("D6", 4), ("C6", 2), ("Bb5", 2), ("A5", 4), ("G5", 4),
        ("G5", 2), ("A5", 2), ("Bb5", 2), ("C6", 2), ("C6", 8),
    ]
    roots = {"F": ("F2", "F3", "C3"), "Dm": ("D2", "D3", "A2"), "Bb": ("Bb1", "Bb2", "F2"),
             "C": ("C2", "C3", "G2"), "Am": ("A1", "A2", "E2")}
    arp = {"F": ["F4", "A4", "C5", "A4"], "Dm": ["D4", "F4", "A4", "F4"], "Bb": ["Bb3", "D4", "F4", "D4"],
           "C": ["C4", "E4", "G4", "E4"], "Am": ["A3", "C4", "E4", "C4"]}
    return song(128, chords, lead, "rfofrfof", roots, arp, "hhchhhchhhchhhch",
                harmony_down=4, gains=[1.0, 0.6, 0.9, 0.55, 0.6])


def el_dorado():
    chords = ["Am", "F", "C", "G", "Am", "F", "E", "E"]
    lead = [
        ("A4", 3), ("C5", 1), ("E5", 4), ("A5", 6), ("G5", 2),
        ("F5", 3), ("E5", 1), ("C5", 4), ("A4", 8),
        ("G4", 3), ("C5", 1), ("E5", 4), ("G5", 4), ("C6", 4),
        ("B5", 6), ("A5", 2), ("G5", 4), ("D5", 4),
        ("E5", 3), ("A5", 1), ("C6", 4), ("B5", 2), ("A5", 2), ("G5", 4),
        ("A5", 3), ("G5", 1), ("F5", 4), ("C6", 8),
        ("B5", 4), ("G#5", 2), ("A5", 2), ("B5", 4), ("E6", 4),
        ("E6", 6), ("D6", 2), ("B5", 4), ("G#5", 4),
    ]
    roots = {"Am": ("A1", "A2", "E2"), "F": ("F1", "F2", "C2"), "C": ("C2", "C3", "G2"),
             "G": ("G1", "G2", "D2"), "E": ("E1", "E2", "B1")}
    arp = {"Am": ["A3", "C4", "E4", "A4"], "F": ["F3", "A3", "C4", "F4"], "C": ["C4", "E4", "G4", "C5"],
           "G": ["G3", "B3", "D4", "G4"], "E": ["E3", "G#3", "B3", "E4"]}
    return song(140, chords, lead, "rrorrfro", roots, arp, "k.h.s.h.k.k.s.h.",
                harmony_down=4, gains=[1.0, 0.7, 1.0, 0.5, 0.95])


def main():
    write_ogg("curse.ogg", curse())
    write_ogg("spirit.ogg", spirit())
    write_ogg("el_dorado.ogg", el_dorado())
    print("wrote curse, spirit and El Dorado music")


if __name__ == "__main__":
    main()
