#!/usr/bin/env python3
"""テスト用のノイズ音声ファイルを生成する。"""

import numpy as np
import wave
import struct

SAMPLE_RATE = 16000
DURATION = 3.0


def write_wav(filename: str, audio: np.ndarray, sample_rate: int = SAMPLE_RATE) -> None:
    audio_int16 = np.clip(audio * 32767, -32768, 32767).astype(np.int16)
    with wave.open(filename, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_int16.tobytes())


def generate_silence() -> np.ndarray:
    return np.zeros(int(SAMPLE_RATE * DURATION), dtype=np.float32)


def generate_typing_noise() -> np.ndarray:
    """打鍵音を模したパルス状ノイズ。短い衝撃音が散発的に入る。"""
    samples = np.zeros(int(SAMPLE_RATE * DURATION), dtype=np.float32)
    num_keystrokes = 8
    for _ in range(num_keystrokes):
        pos = np.random.randint(0, len(samples) - 200)
        duration_samples = np.random.randint(50, 200)
        burst = np.random.randn(duration_samples).astype(np.float32) * 0.15
        envelope = np.exp(-np.linspace(0, 5, duration_samples))
        samples[pos : pos + duration_samples] += burst * envelope
    return samples


if __name__ == "__main__":
    import os

    out_dir = os.path.join(os.path.dirname(__file__), "fixtures")
    os.makedirs(out_dir, exist_ok=True)

    write_wav(os.path.join(out_dir, "silence.wav"), generate_silence())
    print("Generated: silence.wav")

    write_wav(os.path.join(out_dir, "typing_noise.wav"), generate_typing_noise())
    print("Generated: typing_noise.wav")
