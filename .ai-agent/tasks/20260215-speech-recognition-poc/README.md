# 音声認識エンジン PoC

## 目的・ゴール

音声認識エンジン候補を macOS 環境で比較検証し、SpeakPilot に採用するエンジンを決定する。

## 候補エンジン

| エンジン | 統合方法 | 特徴 |
|----------|----------|------|
| MLX Whisper | Python (mlx-whisper) | Apple Silicon 最適化、高精度 |
| Apple Speech Framework | SFSpeechRecognizer (Swift) | ネイティブ API、追加依存なし |
| WhisperKit | Swift Package | CoreML ベース Whisper |

## 完了条件

- [x] 各エンジンの動作確認（または不採用理由の記録）
- [x] 比較結果のドキュメント化
- [x] 採用エンジンの決定

## 結論: Silero VAD + MLX Whisper を採用

### 比較結果

| 観点 | MLX Whisper | Apple Speech | WhisperKit |
|------|-------------|--------------|------------|
| 日本語精度 | 高い (large-v3-turbo) | 中程度 (オンデバイス) | 高い |
| リアルタイム性 | VAD 駆動で発話単位処理 | ストリーミング対応 | チャンク処理 |
| Swift 6 互換性 | Python 実装 (要ブリッジ) | ランタイムクラッシュあり | SPM 統合可 |
| ノイズ耐性 | Silero VAD で高い | なし (ハルシネーション) | 要自前実装 |
| 依存の軽さ | mlx-whisper + silero-vad | なし | WhisperKit (大) |

### 採用理由

1. **Silero VAD による高精度な発話検出**: 無音・打鍵音を完全除外し、発話単位でセグメント分割
2. **MLX Whisper の日本語精度**: TTS 生成音声で 100% 正確な書き起こしを確認
3. **ハルシネーション防止**: 固定チャンク方式では無音時に「ご視聴ありがとうございました」等が出力されたが、VAD 導入で解消
4. **チャンク境界問題の解消**: 固定 3 秒チャンクでは短い発話が欠落したが、VAD の発話区間検出で完全に解決

### 不採用理由

- **Apple Speech Framework**: macOS 26 + Swift 6 環境で `SFSpeechRecognizer.requestAuthorization` コールバックが `@MainActor` 隔離違反で SIGTRAP クラッシュ。根本的に CLI 環境での利用が困難。
- **WhisperKit**: 機能的には問題ないが、MLX Whisper + Silero VAD の組み合わせがより柔軟で、VAD 統合が容易。

### テスト結果

**単体テスト (5/5 passed)**:
- 発話 3 件: 「今日はいい天気ですね」「音声認識のテストを行います」「東京都渋谷区にあるオフィスで会議を行いました」すべて正確に書き起こし
- 無音: VAD で除外
- 打鍵ノイズ: VAD で除外

**ストリームテスト (4/4 passed)**:
- 21 秒の混合ストリーム (無音 + 打鍵ノイズ + 発話 3 件)
- VAD が 3 つの発話区間を正確に検出、ノイズ 0 件検出
- 全発話が完全な文として書き起こされた

## 作業ログ

- 2026-02-15: タスク開始
- 2026-02-15: WhisperKit / Apple Speech の Swift PoC 作成
- 2026-02-15: MLX Whisper / faster-whisper の Python PoC 作成
- 2026-02-15: Apple Speech の Swift 6 クラッシュ問題を発見
- 2026-02-15: 簡易エネルギーベース VAD を実装、限界を確認
- 2026-02-15: Silero VAD 導入、全テスト通過
- 2026-02-15: **採用決定: Silero VAD + MLX Whisper**
