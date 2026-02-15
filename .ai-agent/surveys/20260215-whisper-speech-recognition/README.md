# MLX / WhisperKit による Whisper 音声認識統合調査

## 調査日

2026-02-15

## 概要

macOS / Apple Silicon 向けに Whisper 音声認識を Swift/SPM ベースプロジェクトに統合する方法を調査した。MLX Swift 単体での Whisper 実装、および Argmax 社の WhisperKit を中心に評価する。

---

## 1. MLX Swift の SPM 対応状況

### リポジトリ

- **URL**: https://github.com/ml-explore/mlx-swift
- **ライセンス**: MIT License（Copyright (c) 2023 ml-explore）
- **最新バージョン**: 0.30.x 系（swift-tools-version: 5.12）
- **対応プラットフォーム**: macOS 14.0+, iOS 17+, tvOS 17+, visionOS 1+

### SPM 対応

完全に SPM 対応している。以下のように依存追加可能。

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.30.3")
]
```

提供ライブラリ: `MLX`, `MLXRandom`, `MLXNN`, `MLXOptimizers`, `MLXFFT`, `MLXLinalg`, `MLXFast`

### 注意点

- SwiftPM（コマンドライン）では Metal シェーダーのビルドができないため、最終ビルドは Xcode または `xcodebuild` 経由で行う必要がある
- Apple の Accelerate フレームワークと Metal フレームワークに依存

### MLX Swift での Whisper 実装

**mlx-swift-examples には Whisper 実装は存在しない。** 現在含まれるのは MNIST、Stable Diffusion、LLM 関連のみ。Whisper の Swift ネイティブ実装は MLX エコシステム内では提供されていない。

MLX ベースの Whisper は **Python 版（mlx-whisper）** でのみ提供されている。

---

## 2. WhisperKit（推奨）

### 基本情報

| 項目 | 内容 |
|------|------|
| リポジトリ | https://github.com/argmaxinc/WhisperKit |
| 開発元 | Argmax, Inc. |
| ライセンス | **MIT License** |
| 最新バージョン | v0.15.0 |
| Swift tools version | 5.9 |
| 言語バージョン | Swift 5 |
| 説明 | Apple Silicon 向けオンデバイス音声認識フレームワーク |

### 対応プラットフォーム

| プラットフォーム | 最小バージョン |
|------------------|---------------|
| **macOS** | **13.0+** |
| iOS | 16.0+ |
| watchOS | 10.0+ |
| visionOS | 1.0+ |

macOS 14 をターゲットとする本プロジェクトでは問題なく利用可能。

### SPM 対応

完全に SPM 対応。依存関係は `swift-transformers`（HuggingFace）と `swift-argument-parser` のみ。MLX への依存はない。

#### Package.swift への追加方法

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceInput",
            dependencies: ["WhisperKit"],
            path: "Sources/VoiceInput"
        ),
        .testTarget(
            name: "VoiceInputTests",
            dependencies: ["VoiceInput"],
            path: "Tests/VoiceInputTests"
        ),
    ]
)
```

### 技術アーキテクチャ

WhisperKit は **CoreML** ベースのフレームワークであり、MLX は使用していない。

- Whisper モデルを CoreML 形式に変換して利用
- CoreML が自動的に **Metal GPU** および **Apple Neural Engine (ANE)** を活用
- モデルは HuggingFace（`argmaxinc/whisperkit-coreml`）から自動ダウンロード

### 依存パッケージ

- `swift-transformers`（HuggingFace Hub からのモデルダウンロードとトークナイザー）
- `swift-argument-parser`（CLI ツール用、ライブラリとしての利用時は間接依存）

---

## 3. 基本的な使い方

### ファイル音声の文字起こし

```swift
import WhisperKit

Task {
    // デフォルト設定で初期化（推奨モデルを自動ダウンロード）
    let pipe = try await WhisperKit()

    // 音声ファイルを文字起こし
    let result = try await pipe.transcribe(
        audioPath: "path/to/audio.wav"
    )
    print(result?.text ?? "")
}
```

### モデル指定

```swift
// 特定のモデルを指定
let pipe = try await WhisperKit(WhisperKitConfig(model: "large-v3"))

// distil モデル（高速版）を指定
let pipe = try await WhisperKit(WhisperKitConfig(model: "distil*large-v3"))
```

### 日本語を指定した文字起こし

```swift
let pipe = try await WhisperKit()
let options = DecodingOptions(language: "ja")
let result = try await pipe.transcribe(audioPath: "audio.wav", decodeOptions: options)
```

---

## 4. リアルタイム認識（ストリーミング）

WhisperKit は `AudioStreamTranscriber` クラスによるリアルタイムストリーミング認識をサポートしている。

### 主な機能

- マイクからのリアルタイム音声キャプチャ
- **VAD（Voice Activity Detection）** による音声区間検出
- 確認済みセグメントと未確認セグメントの区別
- バッファベースの逐次認識（1秒以上のバッファで認識実行）
- コールバックによる状態変化通知

### ストリーミング認識の状態

```swift
public struct State {
    public var isRecording: Bool
    public var bufferEnergy: [Float]        // 音声エネルギー
    public var currentText: String           // 現在認識中のテキスト
    public var confirmedSegments: [TranscriptionSegment]   // 確定セグメント
    public var unconfirmedSegments: [TranscriptionSegment] // 未確定セグメント
}
```

### CLI でのストリーミングテスト

```bash
swift run whisperkit-cli transcribe \
    --model-path "Models/whisperkit-coreml/openai_whisper-large-v3" \
    --stream
```

### 注意事項

- WhisperKit のリアルタイム認識は「疑似ストリーミング」で、バッファが 1 秒以上溜まるたびに全体を再認識する方式
- 真のリアルタイムストリーミング（WebSocket ベース等）は有料の **Argmax Pro SDK** で提供
- WhisperKit Local Server は OpenAI 互換 API を持ち、SSE によるストリーミングレスポンスもサポート

---

## 5. 使用可能なモデル

### モデルリポジトリ

HuggingFace: https://huggingface.co/argmaxinc/whisperkit-coreml

### 主なモデルバリアント

| モデル | パラメータ数 | メモリ目安 | 特徴 |
|--------|-------------|-----------|------|
| tiny / tiny.en | 39M | ~30MB | 最小・最速・英語のみ版あり |
| base / base.en | 74M | ~60MB | 小型・英語のみ版あり |
| small / small.en | 244M | ~200MB | バランス型・英語のみ版あり |
| medium / medium.en | 769M | ~600MB | 高精度・英語のみ版あり |
| large-v2 | 1.5B | ~1.5GB | 高精度多言語 |
| large-v3 | 1.5B | ~1.5GB | 最新高精度多言語 |
| large-v3-turbo | 1B | ~800MB | 高速化版 large-v3 |
| distil-large-v3 | - | - | 蒸留モデル（高速） |

### モデルのダウンロード

- **自動ダウンロード**: WhisperKit 初期化時にデバイスに最適なモデルを自動選択・ダウンロード
- **手動指定**: `WhisperKitConfig(model: "large-v3")` でモデル名を指定
- **カスタムモデル**: `WhisperKitConfig(model: "large-v3", modelRepo: "username/your-model-repo")` で独自モデルリポジトリを指定
- **CLI**: `make download-model MODEL=large-v3`

### 推奨モデル（本プロジェクト向け）

- **開発・テスト**: `small` または `base`（軽量で高速）
- **本番・日本語重視**: `large-v3` または `large-v3-turbo`（日本語精度が良い）

---

## 6. 日本語対応

### Whisper モデル自体の日本語性能

- Whisper は 99 言語に対応しており、**日本語は主要対応言語の一つ**
- `large-v3` は `large-v2` と比較して全体的に 10-20% のエラー率低減
- 日本語に関しては `large-v2` と同等以上の精度を維持
- fine-tuned モデル（d750）は英語、ドイツ語、日本語、中国語、フランス語を対象にチューニング済み

### 既知の課題

- 日本語音声認識時に、日本語テキストの間にランダムな英語単語が挿入されることがある（v3 でも継続する課題）
- `language: "ja"` を明示的に指定することで軽減可能
- `small` 以下のモデルでは日本語精度が大幅に低下するため、日本語用途には `medium` 以上を推奨

### 日本語向け推奨設定

```swift
let config = WhisperKitConfig(model: "large-v3")
let pipe = try await WhisperKit(config)
let options = DecodingOptions(language: "ja")
```

---

## 7. Apple Silicon 最適化

### CoreML による最適化

WhisperKit は CoreML ベースのため、Apple Silicon の最適化は CoreML フレームワーク経由で自動的に行われる。

- **Metal GPU**: CoreML が自動的に Metal GPU を活用
- **Apple Neural Engine (ANE)**: CoreML モデルが ANE 対応の場合、自動的に ANE にオフロード
- **Accelerate フレームワーク**: CPU 処理部分で Apple の Accelerate フレームワークを活用

### パフォーマンス

WhisperKit は ICML 2025 で発表された論文によると：

- Apple Silicon 上でリアルタイム以上の速度で large-v3-turbo (1B パラメータ) モデルを動作可能
- デバイスに最適なモデルを自動選択する機能あり
- ベンチマーク結果: https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks

---

## 8. MLX Swift vs WhisperKit 比較

| 観点 | MLX Swift + Whisper | WhisperKit |
|------|---------------------|------------|
| Swift ネイティブ Whisper | なし（Python のみ） | あり |
| SPM 対応 | MLX ライブラリのみ | 完全対応 |
| 推論バックエンド | MLX (Metal) | CoreML (Metal + ANE) |
| ANE 活用 | なし | あり |
| リアルタイム認識 | 自力実装が必要 | AudioStreamTranscriber 提供 |
| モデル配布 | なし（Swift 版） | HuggingFace 自動ダウンロード |
| ライセンス | MIT | MIT |
| 成熟度 | 低（Whisper 未実装） | 高（v0.15.0、ICML 論文あり） |
| 依存関係の軽さ | 重い（MLX C++ ビルド） | 軽い（CoreML のみ） |

---

## 9. 結論と推奨

### 推奨: WhisperKit を採用

本プロジェクト（macOS 14+、SPM ベース、Apple Silicon 最適化、日本語対応、リアルタイム認識が必要）の要件に対して、**WhisperKit が最適な選択**である。

#### 理由

1. **SPM 完全対応** - 1 行の依存追加で統合可能
2. **CoreML + ANE 最適化** - Apple Silicon のフルパフォーマンスを活用
3. **リアルタイム認識内蔵** - AudioStreamTranscriber による VAD 付きストリーミング認識
4. **モデル自動管理** - HuggingFace からの自動ダウンロードとキャッシュ
5. **日本語対応** - Whisper large-v3 による高品質な日本語認識
6. **MIT ライセンス** - 商用利用を含む自由な利用が可能
7. **活発な開発** - Argmax 社による継続的な開発とメンテナンス
8. **macOS ネイティブ** - macOS 13+ 対応で、本プロジェクトの macOS 14+ 要件を満たす

#### MLX Swift を不採用とする理由

- MLX Swift 自体は優れたフレームワークだが、**Swift での Whisper 実装が存在しない**
- Python の mlx-whisper を Swift から呼ぶのは実用的でない
- CoreML の ANE 活用ができない（MLX は Metal GPU のみ）
- リアルタイム認識の仕組みを全て自力実装する必要がある

---

## 参考リンク

- WhisperKit GitHub: https://github.com/argmaxinc/WhisperKit
- WhisperKit CoreML モデル: https://huggingface.co/argmaxinc/whisperkit-coreml
- WhisperKit ベンチマーク: https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks
- MLX Swift GitHub: https://github.com/ml-explore/mlx-swift
- MLX Swift Examples: https://github.com/ml-explore/mlx-swift-examples
- OpenAI Whisper: https://github.com/openai/whisper
- WhisperKit Swift Package Index: https://swiftpackageindex.com/argmaxinc/WhisperKit
- WhisperKit ICML 2025 論文: https://arxiv.org/abs/2507.10860
