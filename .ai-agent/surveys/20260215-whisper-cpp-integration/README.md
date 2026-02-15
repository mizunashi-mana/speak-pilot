# whisper.cpp Swift/macOS 統合調査

## 調査日

2026-02-15

## 調査目的

Swift/macOS プロジェクト（SPM ベース、macOS 14+）に whisper.cpp を統合する方法の調査。

---

## 1. SPM 対応状況

### 公式対応

whisper.cpp 本体リポジトリ（[ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp)）に `Package.swift` が含まれており、SPM から直接参照可能。ただし、unsafe build flags を使用しているため、**バージョン指定ではなくブランチ指定またはコミットハッシュ指定が必要**（SPM の制約）。

旧公式 SPM パッケージ [ggerganov/whisper.spm](https://github.com/ggerganov/whisper.spm) はアーカイブ予定で、本体リポジトリの Package.swift を使うよう案内されている。

### サードパーティラッパー

| パッケージ | URL | Stars | 最終更新 | 特徴 |
|-----------|-----|-------|---------|------|
| **SwiftWhisper** | `https://github.com/exPHAT/SwiftWhisper.git` | ~770 | 2023-08 (v1.2.0) | シンプルな Swift ラッパー、CoreML 対応 |
| **WhisperKit** | `https://github.com/argmaxinc/WhisperKit.git` | ~5,600 | 活発に開発中 | CoreML ネイティブ、リアルタイム対応、Apple 公認 |

### 推奨

- **WhisperKit** が最も活発で機能豊富（リアルタイム対応、VAD、モデル自動ダウンロード）
- whisper.cpp の C interop を直接使う場合は本体リポジトリの Package.swift を利用
- SwiftWhisper は更新が停滞しているため注意

---

## 2. 統合方法

### 方法 A: WhisperKit（推奨）

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
]

// 使用例
import WhisperKit

let pipe = try await WhisperKit(WhisperKitConfig(model: "large-v3-turbo"))
let result = try await pipe.transcribe(audioPath: "path/to/audio.wav")
print(result?.text ?? "")
```

- macOS 14.0+、Xcode 15.0+ が必要
- CoreML ネイティブで Apple Silicon 最適化済み
- モデルは HuggingFace から自動ダウンロード

### 方法 B: whisper.cpp 直接統合（C interop）

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ggml-org/whisper.cpp.git", branch: "master")
]
```

C API を Swift から呼び出す形式。`whisper.h` の関数を直接利用する。

### 方法 C: SwiftWhisper ラッパー

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "1.2.0")
]

// 使用例
import SwiftWhisper

let whisper = Whisper(fromFileURL: modelURL)
let segments = try await whisper.transcribe(audioFrames: pcmFrames) // 16kHz PCM
print(segments.map(\.text).joined())
```

---

## 3. CoreML / Metal 対応

### whisper.cpp

| バックエンド | 状況 | 性能向上 | 備考 |
|------------|------|---------|------|
| **Metal** | 対応済み | GPU でフル推論実行 | Apple Silicon で自動利用 |
| **CoreML** | 対応済み（エンコーダのみ） | CPU 比 3 倍以上高速化 | ANE（Neural Engine）利用、初回はコンパイル遅い |
| **Accelerate** | 対応済み | CPU 最適化 | Apple の BLAS ライブラリ |

CoreML を使う場合、Python スクリプトで GGML モデルを CoreML 形式に変換する必要がある。macOS Sonoma 以降推奨。

### WhisperKit

- CoreML ネイティブ実装のため、追加設定なしで Apple Silicon 最適化
- Neural Engine + GPU + CPU を自動的に最適配分
- モデルは CoreML 形式で配布済み（変換不要）

---

## 4. モデル

### サイズ一覧

| モデル | パラメータ | ディスク | メモリ | 相対速度 |
|-------|-----------|---------|-------|---------|
| tiny | 39M | 75 MiB | ~273 MB | ~10x |
| base | 74M | 142 MiB | ~388 MB | ~7x |
| small | 244M | 466 MiB | ~852 MB | ~4x |
| medium | 769M | 1.5 GiB | ~2.1 GB | ~2x |
| large-v3 | 1550M | 2.9 GiB | ~3.9 GB | 1x |
| **large-v3-turbo** | **809M** | **~1.5 GiB** | **~6 GB** | **~8x** |

各モデルに英語専用 (.en) と多言語版がある（large は多言語のみ）。

### large-v3-turbo について

- large-v3 のデコーダ層を 32 層から 4 層に削減した軽量版
- large-v2 と同等の精度で 6 倍以上高速
- 日本語含む多言語対応
- **本プロジェクトに最も適したモデル候補**

### ダウンロード方法

- **whisper.cpp**: `sh ./models/download-ggml-model.sh base.en` などのスクリプト
- **WhisperKit**: 初期化時に HuggingFace から自動ダウンロード（`WhisperKitConfig(model: "large-v3-turbo")` で指定）

---

## 5. ライセンス

- **whisper.cpp**: MIT License
- **WhisperKit**: MIT License
- **SwiftWhisper**: MIT License
- **Whisper モデル自体**: MIT License（OpenAI）

全てMIT ライセンスで商用利用可能。

---

## 6. リアルタイム認識

### whisper.cpp

- `whisper-stream` ツールで実装済み
- 500ms 間隔でマイク音声をサンプリングし連続認識
- **2 つのモード**:
  - **スライディングウィンドウモード**: 固定間隔で重複セグメントを処理
  - **VAD（音声区間検出）モード**: 音声活動検出後に認識実行（`--step 0` で有効化）
- SDL2 ライブラリが必要（マイク入力用）

### WhisperKit

- リアルタイムストリーミング対応を公式にサポート
- VAD（Voice Activity Detection）内蔵
- Word-level timestamps 対応
- Swift ネイティブで macOS アプリに直接統合しやすい

### SwiftWhisper

- `WhisperDelegate` の `didProcessNewSegments` コールバックで段階的な結果取得が可能
- 真のストリーミング入力ではなくセグメント単位の処理

---

## 7. 日本語対応

### Whisper モデルの日本語性能

- 99 言語対応の中に日本語を含む
- large-v3 は large-v2 比で 10-20% のエラー削減
- 日本語は CER（文字エラー率）で評価（WER ではなく）
- 日本語専用ファインチューニングモデル [kotoba-whisper](https://huggingface.co/kotoba-tech/kotoba-whisper-v2.0) も利用可能（large-v3 比 6.3 倍高速で同等精度）

### 実用上の注意

- 汎用モデルでの日本語認識品質は「良好」だが英語には劣る
- large-v3 / large-v3-turbo で実用的な日本語認識が可能
- 専門用語や固有名詞には追加対策が必要な場合がある

---

## 8. 実績・コミュニティ

### whisper.cpp

- GitHub Stars: **46,700+**（非常に活発）
- ggml-org 管理下で継続的に開発中
- macOS ネイティブアプリでの採用実績多数:
  - [MacWhisper](https://github.com/ggml-org/whisper.cpp/discussions/420): ネイティブ macOS アプリ
  - 多数のミーティング要約ツール、字幕ツール等
- C/C++ 実装のため、あらゆるプラットフォームで利用可能

### WhisperKit

- GitHub Stars: **5,600+**
- Argmax 社が開発（Apple と連携）
- ICML 2025 で論文発表
- Apple の WWDC 2025 で発表された SpeechAnalyzer との統合予定
- Swift/Apple エコシステムとの親和性が最も高い

---

## 総合評価・推奨

### 本プロジェクト（voice-input）への推奨

| 観点 | whisper.cpp (C interop) | WhisperKit |
|------|------------------------|------------|
| SPM 統合の容易さ | △ (unsafe flags, branch指定) | ○ (バージョン指定可) |
| Swift API の使いやすさ | △ (C API ラッパー必要) | ○ (ネイティブ Swift) |
| CoreML/Metal 対応 | ○ (要変換) | ○ (変換不要) |
| リアルタイム対応 | ○ | ○ |
| 日本語品質 | ○ (同じモデル) | ○ (同じモデル) |
| コミュニティ/安定性 | ◎ | ○ |
| macOS ネイティブ親和性 | △ | ◎ |

### 推奨: WhisperKit を第一候補とする

**理由**:
1. Swift ネイティブで SPM 統合が容易（`macOS 14+` 要件にも合致）
2. CoreML ネイティブで変換作業不要
3. リアルタイムストリーミング・VAD が組み込み済み
4. Apple と連携した開発体制（WWDC 2025 / SpeechAnalyzer 統合）
5. モデル自動ダウンロード機能

**whisper.cpp を選ぶケース**:
- より細かい制御が必要な場合
- CoreML 以外のバックエンド（Metal GPU 直接）を使いたい場合
- WhisperKit で対応できないカスタマイズが必要な場合

---

## 参考リンク

- [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) - whisper.cpp 本体
- [argmaxinc/WhisperKit](https://github.com/argmaxinc/WhisperKit) - WhisperKit
- [exPHAT/SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) - SwiftWhisper
- [ggerganov/whisper.spm](https://github.com/ggerganov/whisper.spm) - 旧 SPM パッケージ（アーカイブ予定）
- [openai/whisper](https://github.com/openai/whisper) - オリジナル Whisper
- [kotoba-tech/kotoba-whisper-v2.0](https://huggingface.co/kotoba-tech/kotoba-whisper-v2.0) - 日本語最適化モデル
- [WhisperKit Swift Package Index](https://swiftpackageindex.com/argmaxinc/WhisperKit)
- [SwiftWhisper Swift Package Index](https://swiftpackageindex.com/exPHAT/SwiftWhisper)
