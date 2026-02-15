#!/usr/bin/env python3
"""リアルタイムストリーム処理のシミュレーションテスト。

無音・ノイズ・発話が混在する音声ストリームを Silero VAD でセグメント分割し、
発話単位で MLX Whisper に渡して書き起こしが正しく機能するかを検証する。

タイムライン:
  0.0s -  2.0s : 無音 (2.0s)
  2.0s -  3.9s : 発話 "今日はいい天気ですね" (1.88s)
  3.9s -  7.0s : 無音 (3.1s)
  7.0s -  8.0s : 打鍵ノイズ (1.0s)
  8.0s - 11.0s : 無音 (3.0s)
 11.0s - 13.5s : 発話 "音声認識のテストを行います" (2.53s)
 13.5s - 16.0s : 無音 (2.5s)
 16.0s - 19.9s : 発話 "東京都...会議を行いました" (3.93s)
 19.9s - 21.0s : 無音 (1.1s)
"""

import os
import sys

import numpy as np
import scipy.io.wavfile as wavfile
import torch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mlx_whisper
from silero_vad import VADIterator, load_silero_vad

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")
WHISPER_MODEL = "mlx-community/whisper-large-v3-turbo"
SAMPLE_RATE = 16000
VAD_FRAME_MS = 32
VAD_FRAME_SAMPLES = int(SAMPLE_RATE * VAD_FRAME_MS / 1000)


def load_wav(name: str) -> np.ndarray:
    sr, data = wavfile.read(os.path.join(FIXTURES_DIR, name))
    assert sr == SAMPLE_RATE, f"Expected {SAMPLE_RATE}Hz, got {sr}"
    return data.astype(np.float32) / 32768.0


def rms_db(audio: np.ndarray) -> float:
    rms = np.sqrt(np.mean(audio**2))
    return 20 * np.log10(max(rms, 1e-10))


def generate_typing_noise(duration_s: float) -> np.ndarray:
    n = int(SAMPLE_RATE * duration_s)
    samples = np.zeros(n, dtype=np.float32)
    num_keys = max(1, int(duration_s * 8))
    for _ in range(num_keys):
        pos = np.random.randint(0, max(n - 200, 1))
        dur = min(np.random.randint(50, 200), n - pos)
        burst = np.random.randn(dur).astype(np.float32) * 0.15
        envelope = np.exp(-np.linspace(0, 5, dur))
        samples[pos : pos + dur] += burst * envelope
    return samples


def build_stream() -> tuple[np.ndarray, list[tuple[float, float, str]]]:
    """混合音声ストリームを構築し、発話区間のアノテーションを返す。"""
    speech_weather = load_wav("speech_weather.wav")
    speech_test = load_wav("speech_test.wav")
    speech_long = load_wav("speech_long.wav")

    total_duration = 21.0
    stream = np.zeros(int(SAMPLE_RATE * total_duration), dtype=np.float32)
    segments: list[tuple[float, float, str]] = []

    def place(audio: np.ndarray, start_s: float) -> None:
        start = int(SAMPLE_RATE * start_s)
        end = start + len(audio)
        stream[start:end] += audio

    t = 2.0
    place(speech_weather, t)
    segments.append((t, t + len(speech_weather) / SAMPLE_RATE, "天気"))

    t = 7.0
    place(generate_typing_noise(1.0), t)

    t = 11.0
    place(speech_test, t)
    segments.append((t, t + len(speech_test) / SAMPLE_RATE, "テスト"))

    t = 16.0
    place(speech_long, t)
    segments.append((t, t + len(speech_long) / SAMPLE_RATE, "会議"))

    return stream, segments


def segment_with_vad(
    stream: np.ndarray,
) -> list[tuple[np.ndarray, float, float]]:
    """Silero VAD でストリームを発話セグメントに分割する。

    Returns: [(audio, start_sec, end_sec), ...]
    """
    vad_model = load_silero_vad()
    vad_iterator = VADIterator(
        vad_model,
        threshold=0.5,
        sampling_rate=SAMPLE_RATE,
        min_silence_duration_ms=500,
        speech_pad_ms=100,
    )

    utterances: list[tuple[np.ndarray, float, float]] = []
    speech_frames: list[np.ndarray] = []
    speech_start_sample = 0

    for offset in range(0, len(stream) - VAD_FRAME_SAMPLES + 1, VAD_FRAME_SAMPLES):
        frame = stream[offset : offset + VAD_FRAME_SAMPLES]
        frame_tensor = torch.from_numpy(frame)

        speech_dict = vad_iterator(frame_tensor)
        if speech_dict is not None:
            if "start" in speech_dict:
                speech_frames.clear()
                speech_start_sample = offset
            if "end" in speech_dict:
                if speech_frames:
                    audio = np.concatenate(speech_frames)
                    start_s = speech_start_sample / SAMPLE_RATE
                    end_s = start_s + len(audio) / SAMPLE_RATE
                    utterances.append((audio, start_s, end_s))
                    speech_frames.clear()

        if vad_iterator.triggered:
            speech_frames.append(frame.copy())

    return utterances


def main() -> None:
    stream, speech_segments = build_stream()

    print("=== リアルタイムストリームテスト (Silero VAD) ===")
    print(f"ストリーム長: {len(stream)/SAMPLE_RATE:.1f}s")
    print(f"発話区間: {[(f'{s:.1f}-{e:.1f}s', kw) for s, e, kw in speech_segments]}")
    print()

    # VAD でセグメント分割
    print("--- VAD セグメント分割 ---")
    utterances = segment_with_vad(stream)

    for i, (audio, start, end) in enumerate(utterances):
        db = rms_db(audio)
        print(f"  Utterance {i}: {start:5.2f}-{end:5.2f}s ({end-start:.2f}s, {db:+.1f} dB)")

    print()

    # 各セグメントを Whisper で書き起こし
    print("--- 書き起こし ---")
    all_transcribed: list[str] = []

    for i, (audio, start, end) in enumerate(utterances):
        result = mlx_whisper.transcribe(
            audio, path_or_hf_repo=WHISPER_MODEL, language="ja"
        )
        text = result.get("text", "").strip()
        print(f"  Utterance {i} ({start:.1f}-{end:.1f}s): \"{text}\"")
        if text:
            all_transcribed.append(text)

    print()
    combined = " ".join(all_transcribed)
    print(f"書き起こし結合: {combined}")
    print()

    # 検証
    passed = 0
    failed = 0
    for seg_start, seg_end, keyword in speech_segments:
        if keyword in combined:
            print(f"  PASS: \"{keyword}\" が書き起こされた (発話区間 {seg_start:.1f}-{seg_end:.1f}s)")
            passed += 1
        else:
            print(f"  FAIL: \"{keyword}\" が見つからない (発話区間 {seg_start:.1f}-{seg_end:.1f}s)")
            failed += 1

    # 打鍵ノイズが書き起こされていないことを確認
    # (VAD が発話として検出したセグメント数 == 発話区間の数であるべき)
    if len(utterances) <= len(speech_segments):
        print(f"  PASS: ノイズは検出されなかった (セグメント数: {len(utterances)})")
        passed += 1
    else:
        extra = len(utterances) - len(speech_segments)
        print(f"  FAIL: {extra} 個の余分なセグメントが検出された (ノイズ混入の可能性)")
        failed += 1

    total = passed + failed
    print(f"\n=== 結果: {passed}/{total} passed, {failed}/{total} failed ===")
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
