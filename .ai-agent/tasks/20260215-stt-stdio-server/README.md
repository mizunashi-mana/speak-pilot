# STT Stdio Server

## 目的・ゴール

PoC (`poc/python/realtime_mlx_whisper.py`) を、stdin/stdout JSON lines プロトコルで Swift アプリと通信する STT (Speech-to-Text) サーバにリファクタリングする。

## 依存タスク

なし（独立して実装可能）

## 実装方針

### ファイル構成

```
stt-stdio-server/
  pyproject.toml
  speak_pilot_stt_stdio/
    __init__.py
    __main__.py       # エントリポイント: python -m speak_pilot_stt_stdio
    service.py        # メインサービスループ
    protocol.py       # JSON lines プロトコル型定義
    audio.py          # sounddevice ラッパー
    vad.py            # Silero VAD ラッパー
    transcriber.py    # MLX Whisper ラッパー
```

### プロトコル

**コマンド** (stdin, JSON lines):
- `{"type": "start"}` — 音声キャプチャ + 認識開始
- `{"type": "stop"}` — 認識停止
- `{"type": "shutdown"}` — プロセス終了

**イベント** (stdout, JSON lines):
- `{"type": "ready"}` — 初期化完了
- `{"type": "speech_started"}` — VAD が発話検出
- `{"type": "transcription", "text": "...", "is_final": true}` — 書き起こし結果
- `{"type": "speech_ended"}` — 発話終了
- `{"type": "error", "message": "..."}` — エラー

### モジュール分割

- **protocol.py**: コマンド・イベントの型定義と JSON シリアライズ/パース
- **audio.py**: `sounddevice.InputStream` のラップ。`queue.Queue` でバッファリング（PoC の busy-wait を解消）
- **vad.py**: Silero VAD の初期化 + フレーム処理。`process_frame(frame) -> (VadEvent | None, np.ndarray | None)`
- **transcriber.py**: `mlx_whisper.transcribe()` のラップ。スレッドで非同期実行
- **service.py**: stdin コマンド読み取り → パイプライン制御 → stdout イベント出力
- **__main__.py**: logging 設定 (stderr) + `Service.run()` 呼び出し

### 依存関係

- `mlx-whisper`, `sounddevice`, `numpy`, `silero-vad>=6.2.0`
- PoC にあった `faster-whisper`, `scipy` は不要

## 完了条件

- [x] `stt-stdio-server/` ディレクトリにサービスが実装されている
- [ ] `echo '{"type":"start"}' | uv run --project stt-stdio-server/ python -m speak_pilot_stt_stdio` でイベントが出力される
- [ ] start → speech_started → transcription → speech_ended のイベントフローが動作する
- [ ] shutdown コマンドでクリーンに終了する
- [ ] ログが stderr に出力される（stdout はプロトコル専用）

## 作業ログ

- 2026-02-15: タスク作成
- 2026-02-15: stt-server → stt-stdio-server にリネーム、実装完了
