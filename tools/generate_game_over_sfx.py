#!/opt/homebrew/bin/python3

import math
import random
import struct
import wave
from array import array
from pathlib import Path


SAMPLE_RATE = 44100
DURATION = 1.58
TOTAL_FRAMES = int(SAMPLE_RATE * DURATION)
OUTPUT = Path("sift Shared/music/game_over.wav")


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
        rng = random.Random(7)
        self.noise = [rng.uniform(-1.0, 1.0) for _ in range(65536)]
        self.noise_mask = len(self.noise) - 1

    def add(self, index: int, left: float, right: float) -> None:
        if 0 <= index < TOTAL_FRAMES:
            self.left[index] += left
            self.right[index] += right

    def pan(self, pan: float) -> tuple[float, float]:
        angle = (pan + 1.0) * math.pi * 0.25
        return math.cos(angle), math.sin(angle)

    def add_descending_tone(
        self,
        start: float,
        duration: float,
        start_note: float,
        end_note: float,
        amp: float,
        pan: float,
        shimmer: float,
    ) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        for i in range(frames):
            t = i / SAMPLE_RATE
            progress = min(1.0, t / duration)
            glide = progress * progress
            note = start_note + (end_note - start_note) * glide
            freq = midi_to_freq(note)
            env = (1.0 - math.exp(-65.0 * t)) * math.exp(-3.6 * t)
            core = math.sin(2.0 * math.pi * freq * t)
            overtone = math.sin(2.0 * math.pi * freq * 2.01 * t + 0.2)
            glass = math.sin(2.0 * math.pi * freq * 3.97 * t + 0.8)
            wobble = 0.01 * math.sin(2.0 * math.pi * 5.4 * t)
            sample = amp * env * (0.76 * core + 0.18 * overtone + shimmer * 0.12 * glass + wobble)
            self.add(start_index + i, sample * left_gain, sample * right_gain)

    def add_sub_drop(self, start: float, duration: float, start_freq: float, end_freq: float, amp: float) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        for i in range(frames):
            t = i / SAMPLE_RATE
            progress = min(1.0, t / duration)
            freq = start_freq + (end_freq - start_freq) * (progress * progress)
            env = smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(duration - 0.32, duration, t))
            body = math.sin(2.0 * math.pi * freq * t)
            harmonics = math.sin(2.0 * math.pi * freq * 1.5 * t + 0.4)
            sample = amp * env * (0.86 * body + 0.12 * harmonics)
            self.add(start_index + i, sample * 0.95, sample * 1.05)

    def add_glass_sprinkle(self, start: float, duration: float, center_freq: float, amp: float, pan: float, seed: int) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        for i in range(frames):
            t = i / SAMPLE_RATE
            noise = self.noise[(seed + i * 17) & self.noise_mask]
            env = math.exp(-14.0 * t) * (1.0 - math.exp(-90.0 * t))
            bell = math.sin(2.0 * math.pi * center_freq * t + 0.1)
            bell += 0.5 * math.sin(2.0 * math.pi * center_freq * 1.82 * t + 1.1)
            bell += 0.35 * math.sin(2.0 * math.pi * center_freq * 2.73 * t + 2.0)
            sample = amp * env * (0.74 * bell + 0.18 * noise)
            self.add(start_index + i, sample * left_gain, sample * right_gain)

    def add_reverse_air(self, start: float, duration: float, amp: float) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        previous = 0.0
        for i in range(frames):
            t = i / SAMPLE_RATE
            noise = self.noise[(i * 23) & self.noise_mask]
            hp = noise - previous * 0.86
            previous = noise
            env = smoothstep(0.0, duration, t) * (1.0 - smoothstep(duration - 0.06, duration, t))
            sample = amp * env * hp
            self.add(start_index + i, sample * 0.55, sample * 0.7)

    def add_tail(self, start: float, duration: float, note: float, amp: float, pan: float) -> None:
        start_index = int(start * SAMPLE_RATE)
        frames = int(duration * SAMPLE_RATE)
        left_gain, right_gain = self.pan(pan)
        freq = midi_to_freq(note)
        for i in range(frames):
            t = i / SAMPLE_RATE
            env = (1.0 - math.exp(-18.0 * t)) * math.exp(-2.1 * t)
            sample = amp * env * (
                0.7 * math.sin(2.0 * math.pi * freq * t) +
                0.18 * math.sin(2.0 * math.pi * freq * 2.0 * t + 0.5) +
                0.08 * math.sin(2.0 * math.pi * freq * 4.0 * t + 1.3)
            )
            self.add(start_index + i, sample * left_gain, sample * right_gain)

    def apply_fade(self) -> None:
        fade_frames = int(0.02 * SAMPLE_RATE)
        for i in range(fade_frames):
            gain = i / max(1, fade_frames - 1)
            self.left[i] *= gain
            self.right[i] *= gain
            self.left[-1 - i] *= gain
            self.right[-1 - i] *= gain

    def write(self, path: Path) -> None:
        self.apply_fade()
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

    renderer.add_reverse_air(0.0, 0.20, 0.018)
    renderer.add_descending_tone(0.05, 1.18, 72.0, 57.5, 0.16, -0.18, 0.7)
    renderer.add_descending_tone(0.12, 1.04, 67.0, 52.0, 0.14, 0.26, 0.45)
    renderer.add_glass_sprinkle(0.07, 0.72, 1600.0, 0.06, 0.45, 101)
    renderer.add_glass_sprinkle(0.14, 0.78, 1180.0, 0.05, -0.4, 211)
    renderer.add_glass_sprinkle(0.23, 0.54, 830.0, 0.045, 0.1, 337)
    renderer.add_sub_drop(0.11, 1.08, 84.0, 42.0, 0.19)
    renderer.add_tail(0.42, 1.06, 48.0, 0.05, -0.08)

    renderer.write(OUTPUT)


if __name__ == "__main__":
    build_effect()
