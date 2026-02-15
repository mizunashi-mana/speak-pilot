# Python リアルタイム音声書き起こし PoC

マイクからの音声をリアルタイムで書き起こすスクリプト集。

## セットアップ

[uv](https://docs.astral.sh/uv/) を使用します。

```bash
cd poc/python
uv sync
```

## 使い方

### MLX Whisper 版 (Apple Silicon 推奨)

```bash
uv run realtime_mlx_whisper.py
```

モデルを指定する場合:

```bash
uv run realtime_mlx_whisper.py --model mlx-community/whisper-large-v3-turbo
```

### faster-whisper 版

```bash
uv run realtime_faster_whisper.py
```

モデルを指定する場合:

```bash
uv run realtime_faster_whisper.py --model large-v3-turbo
```

計算精度を指定する場合:

```bash
uv run realtime_faster_whisper.py --compute-type int8
```

### 共通オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `--model` | 使用するモデル名 | MLX: `mlx-community/whisper-large-v3-turbo` / faster: `large-v3-turbo` |
| `--chunk-duration` | 認識チャンクの長さ(秒) | 3.0 |
| `--compute-type` | 計算精度 (faster-whisper のみ) | auto |

## 注意事項

- 初回実行時はモデルのダウンロードが発生するため時間がかかります
- MLX Whisper は Apple Silicon Mac 専用です
- マイクへのアクセス許可が必要です（macOS の場合はシステム設定から許可してください）
- チャンク長を短くすると応答性は上がりますが認識精度が下がる場合があります
