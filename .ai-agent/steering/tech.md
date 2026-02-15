# 技術アーキテクチャ

## 技術スタック

### 言語・フレームワーク

- **UI / システム統合**: Swift + SwiftUI
- **音声認識バックエンド**: Python (mlx-whisper + silero-vad)
- **プラットフォーム**: macOS（Apple Silicon 専用）
- **最小対応 OS**: macOS 14 Sonoma（予定）

### 音声認識エンジン（決定済み）

- **MLX Whisper** (採用): Apple Silicon 最適化された Whisper 実装（Python / MLX フレームワーク）
  - モデル: `large-v3-turbo` をデフォルト使用
  - 日本語認識精度が高く、Apple Silicon の GPU を活用
  - mlx-swift は MLX のテンソル API のみ提供し Whisper モデル実装がないため、Python 版を使用
- **Silero VAD** (採用): ニューラルネット VAD による発話区間検出（Python / PyTorch）
  - 発話の開始・終了を検出し、発話単位で Whisper に渡す
  - 無音時のハルシネーション防止、打鍵音等のノイズ除外
  - CoreML 版 (FluidAudio) も存在するが、バックエンドを Python に統一するため Python 版を使用
- ~~faster-whisper~~: CTranslate2 ベース（MLX Whisper 採用のため不採用）
- ~~Apple Speech Framework~~: Swift 6 の concurrency 制約あり、精度も MLX Whisper に劣る

### Swift ↔ Python 連携（決定済み）

- **IPC 方式**: サブプロセス + stdin/stdout (JSON lines プロトコル)
  - Swift が `Foundation.Process` で Python スクリプトをサブプロセスとして起動
  - コマンド (Swift → Python): `{"type": "start"}`, `{"type": "stop"}`, `{"type": "shutdown"}`
  - イベント (Python → Swift): `{"type": "ready"}`, `{"type": "transcription", "text": "...", "is_final": true}`, etc.
  - ログは stderr へ出力 (stdout はプロトコル専用)
- **開発時起動**: `uv run --project stt-stdio-server/ python -m speak_pilot_stt_stdio`
- **音声キャプチャ**: Python 側 (sounddevice) で実施。Swift 側はキャプチャしない

### システム統合（決定済み）

- **テキスト挿入**: NSPasteboard + CGEvent (Cmd+V シミュレーション)
  - 日本語/Unicode テキストに最も確実な方式
  - Accessibility 権限が必要 (`AXIsProcessTrustedWithOptions` でチェック)
  - クリップボード内容を退避・復元
- **グローバルホットキー**: Carbon `RegisterEventHotKey` (Ctrl+Option+Space)
  - Accessibility 権限不要、最も信頼性の高い方式

## アーキテクチャ概要

```
┌──────────────────────────────────────┐
│          UI Layer (SwiftUI)           │
│    MenuBarExtra / ステータス表示       │
├──────────────────────────────────────┤
│         Application Layer             │
│  AppState / HotkeyManager             │
├───────────────┬──────────────────────┤
│  Swift 側      │  Python バックエンド   │
│  BackendManager│  (サブプロセス)        │
│  TextInserter  │  sounddevice (入力)   │
│  ProcessRunner │  Silero VAD (検出)    │
│                │  MLX Whisper (認識)   │
├───────────────┴──────────────────────┤
│         stdin/stdout JSON lines       │
└──────────────────────────────────────┘
```

## 開発環境

- **IDE**: Xcode
- **ビルドシステム**: Swift Package Manager
- **パッケージ管理**: SPM
- **OS**: macOS（開発機は Apple Silicon 推奨）

## テスト戦略

- Swift Testing フレームワーク (`import Testing`) によるユニットテスト
- Python: pytest によるバックエンドユニットテスト
- UI テスト（XCUITest）は必要に応じて導入

## CI/CD

- 未構築（今後検討）
