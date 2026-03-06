#!/opt/homebrew/bin/python3

import math
import random
import struct
import wave
from array import array
from pathlib import Path


SAMPLE_RATE = 32000
DURATION = 90.0
BPM = 90.0
BEAT = 60.0 / BPM
TOTAL_FRAMES = int(SAMPLE_RATE * DURATION)
OUTPUT = Path("sift Shared/music/bg_music.wav")


def midi_to_freq(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def smoothstep(a: float, b: float, x: float) -> float:
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    t = (x - a) / (b - a)
    return t * t * (3.0 - 2.0 * t)


def section_level(t: float, start: float, fade_in: float, end: float, fade_out: float) -> float:
    return smoothstep(start, start + fade_in, t) * (1.0 - smoothstep(end - fade_out, end, t))


class LoopRenderer:
    def __init__(self) -> None:
        self.left = array("f", [0.0]) * TOTAL_FRAMES
        self.right = array("f", [0.0]) * TOTAL_FRAMES
        rng = random.Random(42)
        self.noise = [rng.uniform(-1.0, 1.0) for _ in range(65536)]
        self.noise_mask = len(self.noise) - 1

    def add_sample(self, index: int, left: float, right: float) -> None:
        slot = index % TOTAL_FRAMES
        self.left[slot] += left
        self.right[slot] += right

    def pan(self, pan: float) -> tuple[float, float]:
        angle = (pan + 1.0) * math.pi * 0.25
        return math.cos(angle), math.sin(angle)

    def add_pad(self, start: float, duration: float, freq: float, amp: float, pan: float, color: float = 0.18) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        detune = 1.0035
        attack = max(0.2, duration * 0.16)
        release = max(0.4, duration * 0.25)
        for i in range(frames):
            t = i / SAMPLE_RATE
            env_attack = min(1.0, t / attack)
            env_release = min(1.0, (duration - t) / release) if t > duration - release else 1.0
            env = math.sin(env_attack * math.pi * 0.5) * math.sin(env_release * math.pi * 0.5)
            wobble = 1.0 + 0.004 * math.sin(2.0 * math.pi * 0.12 * t)
            a = math.sin(2.0 * math.pi * freq * wobble * t)
            b = math.sin(2.0 * math.pi * freq * detune * wobble * t + 0.5)
            c = math.sin(2.0 * math.pi * freq * 2.0 * t + 1.1)
            sample = amp * env * (0.62 * a + 0.28 * b + color * c)
            self.add_sample(start_index + i, sample * left_gain, sample * right_gain)

    def add_pluck(
        self,
        start: float,
        duration: float,
        freq: float,
        amp: float,
        pan: float,
        bright: float = 0.45,
        shimmer: float = 0.0,
    ) -> None:
        taps = [(0.0, 1.0, pan), (0.18, 0.32, max(-1.0, pan - 0.22)), (0.37, 0.18, min(1.0, pan + 0.28))]
        for delay, level, tap_pan in taps:
            start_index = int((start + delay) * SAMPLE_RATE)
            frames = int(duration * SAMPLE_RATE)
            left_gain, right_gain = self.pan(tap_pan)
            for i in range(frames):
                t = i / SAMPLE_RATE
                env = (1.0 - math.exp(-42.0 * t)) * math.exp(-3.8 * t)
                body = math.sin(2.0 * math.pi * freq * t)
                overtone = math.sin(2.0 * math.pi * freq * 2.0 * t + 0.2)
                air = math.sin(2.0 * math.pi * freq * 3.0 * t + 0.6)
                sparkle = math.sin(2.0 * math.pi * freq * 4.0 * t + 1.0)
                chorus = 0.02 * math.sin(2.0 * math.pi * 4.3 * t)
                sample = amp * level * env * (
                    0.76 * body
                    + bright * 0.24 * overtone
                    + bright * 0.11 * air
                    + shimmer * 0.12 * sparkle
                    + chorus
                )
                self.add_sample(start_index + i, sample * left_gain, sample * right_gain)

    def add_bell(self, start: float, duration: float, freq: float, amp: float, pan: float) -> None:
        taps = [(0.0, 1.0, pan), (0.31, 0.24, -pan * 0.8), (0.62, 0.12, pan * 0.5)]
        ratios = (1.0, 2.71, 4.13)
        for delay, level, tap_pan in taps:
            start_index = int((start + delay) * SAMPLE_RATE)
            frames = int(duration * SAMPLE_RATE)
            left_gain, right_gain = self.pan(tap_pan)
            for i in range(frames):
                t = i / SAMPLE_RATE
                env = (1.0 - math.exp(-80.0 * t)) * math.exp(-2.8 * t)
                tone = 0.0
                for idx, ratio in enumerate(ratios):
                    tone += math.sin(2.0 * math.pi * freq * ratio * t + idx * 0.7) * (0.58 / (idx + 1))
                sample = amp * level * env * tone
                self.add_sample(start_index + i, sample * left_gain, sample * right_gain)

    def add_kick(self, start: float, amp: float) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(0.42 * SAMPLE_RATE)
        for i in range(frames):
            t = i / SAMPLE_RATE
            env = math.exp(-8.0 * t)
            freq = 76.0 - 42.0 * min(1.0, t / 0.18)
            body = math.sin(2.0 * math.pi * freq * t)
            click = math.sin(2.0 * math.pi * 1200.0 * t) * math.exp(-40.0 * t)
            sample = amp * (0.88 * env * body + 0.08 * click)
            self.add_sample(start_index + i, sample * 0.92, sample * 1.08)

    def add_hat(self, start: float, amp: float, pan: float, seed: int) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(0.09 * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        previous = 0.0
        for i in range(frames):
            t = i / SAMPLE_RATE
            idx = (seed + i * 19) & self.noise_mask
            noise = self.noise[idx]
            hp = noise - previous * 0.82
            previous = noise
            metallic = math.sin(2.0 * math.pi * 7200.0 * t) + 0.4 * math.sin(2.0 * math.pi * 9100.0 * t + 0.3)
            env = math.exp(-52.0 * t)
            sample = amp * env * (0.72 * hp + 0.28 * metallic)
            self.add_sample(start_index + i, sample * left_gain, sample * right_gain)

    def add_click(self, start: float, amp: float, pan: float, seed: int) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(0.06 * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        for i in range(frames):
            t = i / SAMPLE_RATE
            idx = (seed + i * 11) & self.noise_mask
            noise = self.noise[idx]
            wood = math.sin(2.0 * math.pi * 1800.0 * t) + 0.35 * math.sin(2.0 * math.pi * 940.0 * t + 0.2)
            env = math.exp(-64.0 * t)
            sample = amp * env * (0.42 * noise + 0.58 * wood)
            self.add_sample(start_index + i, sample * left_gain, sample * right_gain)

    def write(self, path: Path) -> None:
        peak = max(max(abs(v) for v in self.left), max(abs(v) for v in self.right), 1.0)
        gain = 0.82 / peak
        with wave.open(str(path), "wb") as wav_file:
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)
            wav_file.setframerate(SAMPLE_RATE)
            frames = bytearray()
            for left, right in zip(self.left, self.right):
                l = max(-32767, min(32767, int(left * gain * 32767.0)))
                r = max(-32767, min(32767, int(right * gain * 32767.0)))
                frames += struct.pack("<hh", l, r)
            wav_file.writeframes(frames)


def build_track() -> None:
    renderer = LoopRenderer()

    cycle = 10.0
    chord_starts = [0.0, 4.0 * BEAT, 8.0 * BEAT, 12.0 * BEAT]
    chord_lengths = [4.0 * BEAT, 4.0 * BEAT, 4.0 * BEAT, 3.0 * BEAT]
    roots = [38, 34, 41, 36]  # D2, Bb1, F2, C2
    pads = [
        [50, 57, 60, 64],  # D3 A3 C4 E4
        [46, 53, 57, 60],  # Bb2 F3 A3 C4
        [53, 57, 60, 64],  # F3 A3 C4 E4
        [48, 55, 59, 62],  # C3 G3 B3 D4
    ]
    motifs = [
        [76, 69, 72],  # E5 A4 C5
        [72, 65, 69],  # C5 F4 A4
        [67, 72, 76],  # G4 C5 E5
        [74, 67, 76],  # D5 G4 E5
    ]

    for cycle_index in range(int(DURATION / cycle)):
        base = cycle_index * cycle
        for chord_index, start in enumerate(chord_starts):
            chord_time = base + start
            chord_len = chord_lengths[chord_index]
            chord_end = chord_time + chord_len
            root_freq = midi_to_freq(roots[chord_index])

            renderer.add_pad(chord_time, chord_len + 0.35, root_freq, 0.22, -0.08, color=0.08)
            renderer.add_pad(chord_time, chord_len + 0.28, root_freq * 2.0, 0.085, 0.1, color=0.16)

            for voicing_index, note in enumerate(pads[chord_index]):
                renderer.add_pad(
                    chord_time + 0.04 * voicing_index,
                    chord_len + 0.16,
                    midi_to_freq(note),
                    0.036 - voicing_index * 0.004,
                    -0.35 + voicing_index * 0.24,
                    color=0.22,
                )

            motif_offsets = [0.0, min(0.78, chord_len * 0.33), min(1.56, chord_len * 0.68)]
            for motif_index, note in enumerate(motifs[chord_index]):
                note_time = chord_time + motif_offsets[motif_index]
                renderer.add_pluck(
                    note_time,
                    1.85,
                    midi_to_freq(note),
                    0.12 - motif_index * 0.01,
                    -0.24 + motif_index * 0.24,
                    bright=0.55,
                    shimmer=0.18,
                )

                octave_layer = section_level(note_time, 45.0, 7.0, 90.0, 15.0)
                if octave_layer > 0.0:
                    renderer.add_pluck(
                        note_time + 0.05,
                        1.4,
                        midi_to_freq(note + 12),
                        0.032 * octave_layer,
                        0.28 - motif_index * 0.22,
                        bright=0.92,
                        shimmer=0.8,
                    )

            if chord_index in (0, 2):
                sparkle_time = chord_time + min(chord_len * 0.72, chord_len - 0.42)
                sparkle_level = 0.038 + 0.016 * section_level(sparkle_time, 45.0, 8.0, 90.0, 15.0)
                renderer.add_bell(sparkle_time, 2.8, midi_to_freq(motifs[chord_index][0] + 12), sparkle_level, 0.45)

            if chord_index == 1:
                renderer.add_bell(chord_time + 0.42, 2.1, midi_to_freq(79), 0.026, -0.42)

            if chord_index == 3:
                renderer.add_bell(chord_end - 0.34, 2.4, midi_to_freq(74), 0.022, 0.12)

        for beat_index in range(15):
            beat_time = base + beat_index * BEAT
            pulse = section_level(beat_time, 15.0, 10.0, 90.0, 15.0)
            if pulse > 0.0 and beat_index in (0, 4, 8, 12):
                renderer.add_kick(beat_time, 0.17 * pulse)

            hat_time = beat_time + BEAT * 0.5
            hat_level = section_level(hat_time, 15.0, 8.0, 90.0, 15.0)
            if hat_level > 0.0:
                renderer.add_hat(hat_time, (0.028 + 0.008 * (beat_index % 2)) * hat_level, -0.25 + 0.04 * (beat_index % 5), cycle_index * 97 + beat_index * 13)

            if pulse > 0.0 and beat_index in (2, 6, 10, 13):
                renderer.add_click(beat_time + BEAT * 0.18, 0.032 * pulse, 0.36 - beat_index * 0.03, cycle_index * 59 + beat_index * 17)

    renderer.write(OUTPUT)


if __name__ == "__main__":
    build_track()
