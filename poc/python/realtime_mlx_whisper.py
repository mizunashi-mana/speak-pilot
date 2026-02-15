#!/usr/bin/env python3
"""MLX Whisper を使ったリアルタイム音声書き起こし

Silero VAD で発話区間を検出し、発話単位で Whisper に渡す。
固定長チャンクではなく発話の開始・終了に基づいてセグメントするため、
短い発話や境界をまたぐ発話も正しく処理できる。
"""

import argparse
import threading
from datetime import datetime

import numpy as np
import sounddevice as sd
import torch

import mlx_whisper
from silero_vad import VADIterator, load_silero_vad

DEFAULT_MODEL = "mlx-community/whisper-large-v3-turbo"
SAMPLE_RATE = 16000
# VAD に渡す 1 フレームの長さ (ms)。Silero VAD は 32ms を推奨。
VAD_FRAME_MS = 32
VAD_FRAME_SAMPLES = int(SAMPLE_RATE * VAD_FRAME_MS / 1000)


def timestamp() -> str:
    return datetime.now().strftime("%H:%M:%S")


def rms_db(audio: np.ndarray) -> float:
    rms = np.sqrt(np.mean(audio**2))
    return 20 * np.log10(max(rms, 1e-10))


def main():
    parser = argparse.ArgumentParser(description="MLX Whisper リアルタイム書き起こし")
    parser.add_argument(
        "--model", default=DEFAULT_MODEL, help=f"モデル名 (default: {DEFAULT_MODEL})"
    )
    parser.add_argument(
        "--vad-threshold",
        type=float,
        default=0.5,
        help="VAD 発話判定閾値 (default: 0.5)",
    )
    parser.add_argument(
        "--min-silence-ms",
        type=int,
        default=500,
        help="発話終了とみなす無音の長さ ms (default: 500)",
    )
    parser.add_argument(
        "--speech-pad-ms",
        type=int,
        default=100,
        help="発話前後に付加するパディング ms (default: 100)",
    )
    args = parser.parse_args()

    # Silero VAD 初期化
    vad_model = load_silero_vad()
    vad_iterator = VADIterator(
        vad_model,
        threshold=args.vad_threshold,
        sampling_rate=SAMPLE_RATE,
        min_silence_duration_ms=args.min_silence_ms,
        speech_pad_ms=args.speech_pad_ms,
    )

    # 音声バッファ (マイクコールバック → メインループ)
    raw_buffer: list[np.ndarray] = []
    buffer_lock = threading.Lock()

    # 書き起こし中フラグ
    is_transcribing = False
    transcribe_lock = threading.Lock()

    # VAD が検出中の発話を蓄積するバッファ
    speech_buffer: list[np.ndarray] = []

    def audio_callback(indata, frames, time_info, status):
        if status:
            print(f"Audio status: {status}")
        with buffer_lock:
            raw_buffer.append(indata[:, 0].copy())

    def transcribe_utterance(audio_data: np.ndarray):
        nonlocal is_transcribing
        try:
            db = rms_db(audio_data)
            duration = len(audio_data) / SAMPLE_RATE
            result = mlx_whisper.transcribe(
                audio_data,
                path_or_hf_repo=args.model,
                language="ja",
            )
            text = result.get("text", "").strip()
            if text:
                print(f"[{timestamp()}] ({db:+.1f} dB, {duration:.1f}s) {text}")
        finally:
            with transcribe_lock:
                is_transcribing = False

    print(f"モデル: {args.model}")
    print(f"VAD: threshold={args.vad_threshold}, "
          f"min_silence={args.min_silence_ms}ms, "
          f"speech_pad={args.speech_pad_ms}ms")
    print("録音開始... (Ctrl+C で終了)")
    print("---")

    try:
        with sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype=np.float32,
            blocksize=VAD_FRAME_SAMPLES,
            callback=audio_callback,
        ):
            while True:
                # マイクからの入力を取得
                with buffer_lock:
                    if not raw_buffer:
                        continue
                    chunks = list(raw_buffer)
                    raw_buffer.clear()

                # 各フレームを VAD に通す
                audio = np.concatenate(chunks)
                for offset in range(0, len(audio) - VAD_FRAME_SAMPLES + 1, VAD_FRAME_SAMPLES):
                    frame = audio[offset : offset + VAD_FRAME_SAMPLES]
                    frame_tensor = torch.from_numpy(frame)

                    speech_dict = vad_iterator(frame_tensor)
                    if speech_dict is not None:
                        if "start" in speech_dict:
                            speech_buffer.clear()
                        if "end" in speech_dict:
                            # 発話終了 → 蓄積した音声を Whisper へ
                            if speech_buffer:
                                utterance = np.concatenate(speech_buffer)
                                speech_buffer.clear()

                                with transcribe_lock:
                                    if is_transcribing:
                                        # 前の書き起こしが終わっていない場合はスキップ
                                        continue
                                    is_transcribing = True

                                thread = threading.Thread(
                                    target=transcribe_utterance,
                                    args=(utterance,),
                                    daemon=True,
                                )
                                thread.start()

                    # VAD が発話中と判断している間はバッファに追加
                    if vad_iterator.triggered:
                        speech_buffer.append(frame.copy())

    except KeyboardInterrupt:
        print("\n終了します")
    except sd.PortAudioError as e:
        print(f"マイクエラー: {e}")
        print("マイクが接続されているか確認してください")


if __name__ == "__main__":
    main()
