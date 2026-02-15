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

### Python 依存の方針

Swift アプリから Python バックエンドを呼び出す。連携方式は要設計（候補: サブプロセス + IPC、ローカル HTTP/WebSocket サーバ、組み込み Python ランタイム等）。

### システム統合

- **入力方式**: macOS Input Method / Accessibility API / CGEvent による他アプリへのテキスト挿入（要調査）
- **音声キャプチャ**: AVFoundation / Core Audio（Swift 側）または sounddevice（Python 側）

## アーキテクチャ概要

```
┌─────────────────────────────────┐
│         UI Layer (SwiftUI)       │
│    ステータスバー / オーバーレイ    │
├─────────────────────────────────┤
│       Application Layer          │
│   入力制御 / セッション管理        │
├──────────────┬──────────────────┤
│  Swift 側     │  Python バックエンド │
│  ホットキー    │  Silero VAD        │
│  テキスト挿入  │  MLX Whisper       │
│  音声キャプチャ │  (IPC で連携)      │
└──────────────┴──────────────────┘
```

## 開発環境

- **IDE**: Xcode
- **ビルドシステム**: Swift Package Manager
- **パッケージ管理**: SPM
- **OS**: macOS（開発機は Apple Silicon 推奨）

## テスト戦略

- XCTest によるユニットテスト
- UI テスト（XCUITest）は必要に応じて導入

## CI/CD

- 未構築（今後検討）
