#!/usr/bin/env python3
"""MLX Whisper 書き起こしの単体テスト。

テスト音声ファイルに対して Silero VAD + Whisper の書き起こしを実行し、
- 発話音声: 期待テキストが含まれるか
- 無音/ノイズ: VAD で除外されるか
を検証する。
"""

import os
import sys

import numpy as np
import scipy.io.wavfile as wavfile
import torch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mlx_whisper
from silero_vad import load_silero_vad, get_speech_timestamps

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")
MODEL = "mlx-community/whisper-large-v3-turbo"
SAMPLE_RATE = 16000


def load_wav(name: str) -> np.ndarray:
    sr, data = wavfile.read(os.path.join(FIXTURES_DIR, name))
    assert sr == SAMPLE_RATE, f"Expected {SAMPLE_RATE}Hz, got {sr}"
    return data.astype(np.float32) / 32768.0


def has_speech(audio: np.ndarray, vad_model) -> bool:
    """Silero VAD で発話が含まれるか判定する。"""
    tensor = torch.from_numpy(audio)
    timestamps = get_speech_timestamps(tensor, vad_model, sampling_rate=SAMPLE_RATE)
    return len(timestamps) > 0


def transcribe(audio: np.ndarray) -> str:
    result = mlx_whisper.transcribe(audio, path_or_hf_repo=MODEL, language="ja")
    return result.get("text", "").strip()


# --- テストケース ---

SPEECH_CASES = [
    ("speech_weather.wav", "天気"),
    ("speech_test.wav", "テスト"),
    ("speech_long.wav", "会議"),
]

NOISE_CASES = [
    "silence.wav",
    "typing_noise.wav",
]


def main() -> None:
    vad_model = load_silero_vad()

    passed = 0
    failed = 0
    total = len(SPEECH_CASES) + len(NOISE_CASES)

    print(f"=== 書き起こしテスト ({total} cases) ===\n")

    # 発話テスト: VAD を通過し、期待キーワードが書き起こされること
    for wav_name, expected_keyword in SPEECH_CASES:
        audio = load_wav(wav_name)
        detected = has_speech(audio, vad_model)
        label = f"[speech] {wav_name}"

        if not detected:
            print(f"FAIL {label}: VAD で発話が検出されなかった")
            failed += 1
            continue

        text = transcribe(audio)
        if expected_keyword in text:
            print(f"PASS {label}: \"{text}\"")
            passed += 1
        else:
            print(f"FAIL {label}: \"{expected_keyword}\" が見つからない (got: \"{text}\")")
            failed += 1

    # ノイズテスト: VAD で除外されること
    for wav_name in NOISE_CASES:
        audio = load_wav(wav_name)
        detected = has_speech(audio, vad_model)
        label = f"[noise] {wav_name}"

        if not detected:
            print(f"PASS {label}: VAD で除外")
            passed += 1
        else:
            text = transcribe(audio)
            print(f"FAIL {label}: VAD が発話と誤検出 (text=\"{text}\")")
            failed += 1

    print(f"\n=== 結果: {passed}/{total} passed, {failed}/{total} failed ===")
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
