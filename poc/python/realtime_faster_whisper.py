#!/usr/bin/env python3
"""faster-whisper を使ったリアルタイム音声書き起こし"""

import argparse
import threading
import time
from datetime import datetime

import numpy as np
import sounddevice as sd

from faster_whisper import WhisperModel

DEFAULT_MODEL = "large-v3-turbo"
SAMPLE_RATE = 16000
CHUNK_DURATION = 3.0


def main():
    parser = argparse.ArgumentParser(
        description="faster-whisper リアルタイム書き起こし"
    )
    parser.add_argument(
        "--model", default=DEFAULT_MODEL, help=f"モデル名 (default: {DEFAULT_MODEL})"
    )
    parser.add_argument(
        "--compute-type",
        default="auto",
        help="計算精度 (default: auto)",
    )
    parser.add_argument(
        "--chunk-duration",
        type=float,
        default=CHUNK_DURATION,
        help=f"チャンク長(秒) (default: {CHUNK_DURATION})",
    )
    args = parser.parse_args()

    print(f"モデル: {args.model}")
    print("モデル読み込み中...")
    model = WhisperModel(args.model, compute_type=args.compute_type)
    print("モデル読み込み完了")

    audio_buffer = []
    buffer_lock = threading.Lock()
    is_transcribing = False
    transcribe_lock = threading.Lock()

    def audio_callback(indata, frames, time_info, status):
        if status:
            print(f"Audio status: {status}")
        with buffer_lock:
            audio_buffer.append(indata[:, 0].copy())

    def transcribe_chunk(audio_data):
        nonlocal is_transcribing
        try:
            rms = np.sqrt(np.mean(audio_data**2))
            rms_db = 20 * np.log10(max(rms, 1e-10))
            segments, _ = model.transcribe(audio_data, language="ja")
            text = "".join(segment.text for segment in segments).strip()
            timestamp = datetime.now().strftime("%H:%M:%S")
            if text:
                print(f"[{timestamp}] ({rms_db:+.1f} dB) {text}")
            else:
                print(f"[{timestamp}] ({rms_db:+.1f} dB) (無音)")
        finally:
            with transcribe_lock:
                is_transcribing = False

    print("録音開始... (Ctrl+C で終了)")

    try:
        with sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype=np.float32,
            callback=audio_callback,
        ):
            while True:
                time.sleep(args.chunk_duration)

                with buffer_lock:
                    if not audio_buffer:
                        continue
                    chunk = np.concatenate(audio_buffer)
                    audio_buffer.clear()

                with transcribe_lock:
                    if is_transcribing:
                        continue
                    is_transcribing = True

                thread = threading.Thread(
                    target=transcribe_chunk, args=(chunk,), daemon=True
                )
                thread.start()

    except KeyboardInterrupt:
        print("\n終了します")
    except sd.PortAudioError as e:
        print(f"マイクエラー: {e}")
        print("マイクが接続されているか確認してください")


if __name__ == "__main__":
    main()
