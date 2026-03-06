#!/opt/homebrew/bin/python3

import math
import random
import struct
import wave
from array import array
from pathlib import Path


SAMPLE_RATE = 44100
DURATION = 2.4
TOTAL_FRAMES = int(SAMPLE_RATE * DURATION)
OUTPUT = Path("sift Shared/music/lvl_completed.wav")


def midi_to_freq(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def smoothstep(a: float, b: float, x: float) -> float:
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    t = (x - a) / (b - a)
    return t * t * (3.0 - 2.0 * t)


class EffectRenderer:
    def __init__(self) -> None:
        self.left = array("f", [0.0]) * TOTAL_FRAMES
        self.right = array("f", [0.0]) * TOTAL_FRAMES
        rng = random.Random(19)
        self.noise = [rng.uniform(-1.0, 1.0) for _ in range(65536)]
        self.noise_mask = len(self.noise) - 1

    def add(self, index: int, left: float, right: float) -> None:
        if 0 <= index < TOTAL_FRAMES:
            self.left[index] += left
            self.right[index] += right

    def pan(self, pan: float) -> tuple[float, float]:
        angle = (pan + 1.0) * math.pi * 0.25
        return math.cos(angle), math.sin(angle)

    def add_pad(self, start: float, duration: float, note: float, amp: float, pan: float, color: float) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        freq = midi_to_freq(note)
        for i in range(frames):
            t = i / SAMPLE_RATE
            env = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(duration - 0.55, duration, t))
            drift = 1.0 + 0.003 * math.sin(2.0 * math.pi * 0.9 * t)
            core = math.sin(2.0 * math.pi * freq * drift * t)
            detune = math.sin(2.0 * math.pi * freq * 1.004 * drift * t + 0.4)
            air = math.sin(2.0 * math.pi * freq * 2.0 * t + 1.0)
            sample = amp * env * (0.68 * core + 0.2 * detune + color * 0.14 * air)
            self.add(start_index + i, sample * left_gain, sample * right_gain)

    def add_pluck(self, start: float, note: float, duration: float, amp: float, pan: float, shimmer: float) -> None:
        taps = [(0.0, 1.0, pan), (0.18, 0.3, max(-1.0, pan - 0.2)), (0.34, 0.14, min(1.0, pan + 0.25))]
        freq = midi_to_freq(note)
        for delay, level, tap_pan in taps:
            start_index = int((start + delay) * SAMPLE_RATE)
            frames = int(duration * SAMPLE_RATE)
            left_gain, right_gain = self.pan(tap_pan)
            for i in range(frames):
                t = i / SAMPLE_RATE
                env = (1.0 - math.exp(-48.0 * t)) * math.exp(-3.2 * t)
                tone = math.sin(2.0 * math.pi * freq * t)
                overtone = math.sin(2.0 * math.pi * freq * 2.0 * t + 0.25)
                sparkle = math.sin(2.0 * math.pi * freq * 4.03 * t + 0.8)
                sample = amp * level * env * (0.74 * tone + 0.18 * overtone + shimmer * 0.12 * sparkle)
                self.add(start_index + i, sample * left_gain, sample * right_gain)

    def add_bell(self, start: float, note: float, duration: float, amp: float, pan: float, seed: int) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        freq = midi_to_freq(note)
        for i in range(frames):
            t = i / SAMPLE_RATE
            env = (1.0 - math.exp(-90.0 * t)) * math.exp(-2.7 * t)
            noise = self.noise[(seed + i * 17) & self.noise_mask]
            tone = math.sin(2.0 * math.pi * freq * t)
            tone += 0.46 * math.sin(2.0 * math.pi * freq * 2.72 * t + 0.7)
            tone += 0.28 * math.sin(2.0 * math.pi * freq * 4.1 * t + 1.4)
            sample = amp * env * (0.86 * tone + 0.08 * noise)
            self.add(start_index + i, sample * left_gain, sample * right_gain)

    def add_sub(self, start: float, duration: float, start_freq: float, end_freq: float, amp: float) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        for i in range(frames):
            t = i / SAMPLE_RATE
            progress = min(1.0, t / duration)
            freq = start_freq + (end_freq - start_freq) * (1.0 - (1.0 - progress) * (1.0 - progress))
            env = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(duration - 0.5, duration, t))
            sample = amp * env * (
                0.88 * math.sin(2.0 * math.pi * freq * t) +
                0.08 * math.sin(2.0 * math.pi * freq * 1.5 * t + 0.4)
            )
            self.add(start_index + i, sample * 0.96, sample * 1.04)

    def add_air(self, start: float, duration: float, amp: float, pan: float, seed: int) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        previous = 0.0
        for i in range(frames):
            t = i / SAMPLE_RATE
            noise = self.noise[(seed + i * 29) & self.noise_mask]
            hp = noise - previous * 0.82
            previous = noise
            env = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(duration - 0.35, duration, t))
            self.add(start_index + i, amp * env * hp * left_gain, amp * env * hp * right_gain)

    def fade_edges(self) -> None:
        fade_frames = int(0.02 * SAMPLE_RATE)
        for i in range(fade_frames):
            gain = i / max(1, fade_frames - 1)
            self.left[i] *= gain
            self.right[i] *= gain
            self.left[-1 - i] *= gain
            self.right[-1 - i] *= gain

    def write(self, path: Path) -> None:
        self.fade_edges()
        peak = max(max(abs(v) for v in self.left), max(abs(v) for v in self.right), 1.0)
        gain = 0.84 / peak
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


def build_effect() -> None:
    renderer = EffectRenderer()

    renderer.add_air(0.0, 0.9, 0.012, -0.18, 41)
    renderer.add_sub(0.0, 1.8, 62.0, 92.0, 0.12)

    chord = [62.0, 65.0, 69.0, 72.0]  # D major 9 color
    for idx, note in enumerate(chord):
        renderer.add_pad(0.04 + idx * 0.015, 1.95, note, 0.07 - idx * 0.008, -0.32 + idx * 0.22, 0.9)

    plucks = [
        (0.02, 74.0, -0.3, 0.7),
        (0.22, 77.0, 0.18, 0.8),
        (0.42, 81.0, -0.08, 0.95),
    ]
    for when, note, pan, shimmer in plucks:
        renderer.add_pluck(when, note, 1.2, 0.12, pan, shimmer)

    bells = [
        (0.14, 86.0, 1.8, 0.05, 0.42, 101),
        (0.36, 89.0, 1.6, 0.042, -0.38, 217),
        (0.66, 93.0, 1.2, 0.035, 0.12, 331),
    ]
    for when, note, duration, amp, pan, seed in bells:
        renderer.add_bell(when, note, duration, amp, pan, seed)

    renderer.write(OUTPUT)


if __name__ == "__main__":
    build_effect()
