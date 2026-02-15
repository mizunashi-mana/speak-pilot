# 技術アーキテクチャ

## 技術スタック

### 言語・フレームワーク

- **言語**: Swift
- **プラットフォーム**: macOS（Apple Silicon 対応）
- **UI フレームワーク**: SwiftUI
- **最小対応 OS**: macOS 14 Sonoma（予定）

### 音声認識エンジン（検討中）

- **MLX Whisper**: Apple Silicon 最適化された Whisper 実装（MLX フレームワーク）
- **faster-whisper**: CTranslate2 ベースの高速 Whisper 実装
- **Apple Speech Framework**: macOS 標準の音声認識 API（品質要件次第で検討）

### システム統合

- **入力方式**: macOS Input Method / Accessibility API / CGEvent による他アプリへのテキスト挿入（要調査）
- **音声キャプチャ**: AVFoundation / Core Audio

## アーキテクチャ概要

```
┌─────────────────────────────────┐
│         UI Layer (SwiftUI)       │
│    ステータスバー / オーバーレイ    │
├─────────────────────────────────┤
│       Application Layer          │
│   入力制御 / セッション管理        │
├─────────────────────────────────┤
│       Recognition Layer          │
│   音声認識エンジン統合             │
│   (MLX Whisper / faster-whisper) │
├─────────────────────────────────┤
│        Audio Layer               │
│   マイク入力 / 音声キャプチャ      │
├─────────────────────────────────┤
│      System Integration          │
│   テキスト挿入 / ホットキー        │
└─────────────────────────────────┘
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
