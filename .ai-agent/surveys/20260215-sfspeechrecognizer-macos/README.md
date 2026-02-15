# Apple Speech Framework（SFSpeechRecognizer）macOS 調査

## 調査日

2026-02-15

## 概要

macOS 14+ での SFSpeechRecognizer を使った音声認識の利用可能性、制約、実装方法を調査した。

---

## 1. macOS 対応状況

### 利用可能性

- SFSpeechRecognizer は **macOS 10.15 (Catalina) 以降**で利用可能
- macOS ネイティブアプリ（AppKit / SwiftUI）および Mac Catalyst アプリの両方で使用可能
- macOS 14 Sonoma / macOS 15 Sequoia でも引き続き利用可能

### 制約

- macOS では iOS と比べて Speech Framework の情報やサンプルコードが少ない
- Apple Developer Forums でも macOS 固有の問題報告がいくつかある（音声認識が動作しないケースなど）
- Apple は WWDC 2025 で後継 API「SpeechAnalyzer」を発表しており、SFSpeechRecognizer は将来的に非推奨になる可能性がある

---

## 2. オフライン認識（オンデバイス認識）

### サポート状況

- **macOS ではすべての Mac デバイスでオンデバイス認識がサポートされている**
- `supportsOnDeviceRecognition` プロパティで対応状況を確認可能
- `SFSpeechRecognitionRequest.requiresOnDeviceRecognition = true` でオンデバイス認識を強制可能

### オンデバイス対応言語

- オンデバイス認識は **約 10〜20 言語**で対応（OS バージョンにより変動）
- **日本語（ja-JP）はオンデバイス認識の対応言語に含まれている**（iOS 15 以降の調査で確認）
- 正確な対応言語リストは `SFSpeechRecognizer.supportedLocales()` と `supportsOnDeviceRecognition` で実行時に確認する必要がある

### オンデバイス vs サーバーベース

| 項目 | オンデバイス | サーバーベース |
|------|------------|--------------|
| ネットワーク | 不要 | 必要 |
| レイテンシ | 低い | ネットワーク依存 |
| 認識精度 | やや低い | 高い |
| 時間制限 | なし | 1分/リクエスト |
| リクエスト数制限 | なし | 1000回/時間/デバイス |
| 対応言語 | 約10〜20言語 | 50言語以上 |
| プライバシー | 音声データが外部に送信されない | Appleサーバーに送信 |

---

## 3. 日本語対応

### 対応状況

- 日本語（ja-JP）は SFSpeechRecognizer の **サーバーベース認識・オンデバイス認識の両方で対応**
- macOS の言語設定で日本語キーボード・音声入力が有効であれば利用可能

### 品質

- サーバーベース認識は比較的高品質
- オンデバイス認識はサーバーベースと比べてやや精度が落ちるが、一般的な会話・文章の認識は実用レベル
- 専門用語や固有名詞の認識精度はカスタム語彙の登録で改善可能（WWDC 2023 で導入された Custom Language Model / Custom Vocabulary 機能）

---

## 4. リアルタイム認識

### サポート状況

- **リアルタイム（ストリーミング）認識を完全サポート**
- `SFSpeechAudioBufferRecognitionRequest` を使用してマイク入力からリアルタイムに音声を認識
- 部分的な認識結果（partial results）をリアルタイムに取得可能
- `AVAudioEngine` と組み合わせてオーディオパイプラインを構築

### 仕組み

1. `AVAudioEngine` でマイク入力をキャプチャ
2. オーディオバッファを `SFSpeechAudioBufferRecognitionRequest` に追加
3. `SFSpeechRecognizer.recognitionTask()` で認識タスクを開始
4. コールバック/デリゲートで部分的・最終的な認識結果を受信
5. 認識終了時に `endAudio()` を呼び出し

---

## 5. API の使い方（コード例）

### マイク入力からのリアルタイム認識（macOS 向け）

```swift
import Speech
import AVFoundation

class SpeechRecognitionManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false

    // 権限リクエスト
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    break
                }
            }
        }
    }

    // オンデバイス認識の対応チェック
    func checkOnDeviceSupport() -> Bool {
        return speechRecognizer.supportsOnDeviceRecognition
    }

    // 認識開始
    func startRecording() throws {
        // 既存タスクのキャンセル
        recognitionTask?.cancel()
        recognitionTask = nil

        // 認識リクエストの設定
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create recognition request")
        }

        // 部分的な結果を有効化
        recognitionRequest.shouldReportPartialResults = true

        // オンデバイス認識を強制（オフライン動作を保証）
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        // 認識タスクの開始
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if result.isFinal {
                    self.stopRecording()
                }
            }

            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                self.stopRecording()
            }
        }

        // オーディオエンジンの設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
    }

    // 認識停止
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
```

---

## 6. 権限・Entitlement

### Info.plist に必要なキー

```xml
<!-- 音声認識の使用目的 -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>音声入力のために音声認識を使用します</string>

<!-- マイクの使用目的 -->
<key>NSMicrophoneUsageDescription</key>
<string>音声入力のためにマイクを使用します</string>
```

### Entitlements（App Sandbox 有効時）

```xml
<!-- App Sandbox の有効化 -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- マイクアクセス（Audio Input） -->
<key>com.apple.security.device.audio-input</key>
<true/>
```

### 補足

- `NSSpeechRecognitionUsageDescription` は必須。未設定だとクラッシュする
- `NSMicrophoneUsageDescription` はマイク入力使用時に必須
- macOS では `SFSpeechRecognizer.requestAuthorization()` でユーザーに許可を求める
- システム環境設定の「プライバシーとセキュリティ」>「音声認識」にアプリが表示される

---

## 7. 精度：Whisper 系との比較

### SFSpeechRecognizer（現行）

- サーバーベース認識は Apple のサーバーモデルを使用しており、一般的な会話では実用的な精度
- オンデバイス認識はサーバーベースより精度が劣る
- 具体的な WER（Word Error Rate）は公開されていない
- 定量的なベンチマーク比較は存在しないが、Whisper Large モデルと比較するとオンデバイス認識は精度で劣ると推定される

### Whisper 系（参考）

- Whisper Large V3: クリーンな英語音声で WER 2〜5%
- 日本語でも高い認識精度を持つ（多言語学習モデル）
- whisper.cpp / MLX Whisper で Apple Silicon 上でのローカル実行が可能

### SpeechAnalyzer（Apple 次世代 API / WWDC 2025）

- **macOS 26 Tahoe / iOS 26 で導入予定**
- MacWhisper（Whisper Large V3 Turbo）と比較して **約 2.2 倍高速**
- 34分の動画ファイルを 45 秒で処理（MacWhisper は 1 分 41 秒）
- 認識精度は Whisper 中〜上位モデルと同等レベル
- 長時間音声・遠距離音声にも対応
- Neural Engine（Apple Silicon）を活用した効率的な処理

### 評価まとめ

| エンジン | 認識精度 | 速度 | 導入容易性 | 利用可能時期 |
|---------|---------|------|-----------|------------|
| SFSpeechRecognizer（オンデバイス） | 中 | 高速 | 容易（標準API） | 現在利用可能 |
| SFSpeechRecognizer（サーバー） | 中〜高 | ネットワーク依存 | 容易（標準API） | 現在利用可能 |
| whisper.cpp / MLX Whisper | 高 | モデルサイズ依存 | 中（外部依存） | 現在利用可能 |
| SpeechAnalyzer | 高 | 非常に高速 | 容易（標準API） | macOS 26以降 |

---

## 8. 制限事項

### サーバーベース認識の制限

- **音声時間**: 1 リクエストあたり最大 **1 分**（超過すると認識が停止）
- **リクエスト数**: デバイスあたり **1,000 リクエスト/時間**（アプリ単位ではなくデバイス単位）
- **ネットワーク**: インターネット接続が必要

### オンデバイス認識の制限

- 時間制限・リクエスト数制限は **なし**
- 対応言語が限定的
- 認識精度がサーバーベースより低い

### 共通の制限

- `SFSpeechRecognizer` は同時に 1 つの認識タスクしか実行できない
- 連続的な長時間認識では、定期的にセッションを再開始する運用が必要（特にサーバーベース）
- バックグラウンドでの音声認識にはバックグラウンドモードの設定が必要

---

## 9. Sandbox 対応

### App Sandbox での動作

- **App Sandbox 環境下で SFSpeechRecognizer は動作する**
- 必要な entitlement:
  - `com.apple.security.device.audio-input` (マイクアクセス)
- Xcode の Signing & Capabilities で App Sandbox の「Audio Input」にチェック
- サーバーベース認識を使用する場合は、ネットワークアクセスの entitlement も必要:
  - `com.apple.security.network.client` (アウトバウンドネットワーク)

### Mac App Store 配布時の注意

- Mac App Store 配布には App Sandbox が必須
- 音声認識・マイクアクセスの権限は App Review で審査される
- `NSSpeechRecognitionUsageDescription` の説明文が適切でないとリジェクトされる可能性がある

---

## 10. 将来の展望：SpeechAnalyzer

### 概要

- WWDC 2025 で発表された **SpeechAnalyzer** は SFSpeechRecognizer の後継 API
- macOS 26 (Tahoe) / iOS 26 以降で利用可能
- Swift ネイティブの新しい API 設計
- Notes、Voice Memos、Journal などのシステムアプリで既に採用

### 主な改善点

- 長時間音声のサポート（会議、講義など）
- 遠距離音声の認識改善
- Whisper 系と同等以上の認識精度
- Neural Engine を活用した高速処理
- `SpeechTranscriber` モジュールによる柔軟な音声解析

### VoiceInput プロジェクトへの影響

- macOS 14 をターゲットとする現プロジェクトでは SpeechAnalyzer は使用不可
- 将来的に最小対応 OS を macOS 26 に引き上げた場合に移行を検討
- 現時点では SFSpeechRecognizer または whisper.cpp / MLX Whisper を使用

---

## 11. VoiceInput プロジェクトへの推奨

### SFSpeechRecognizer の採用判断

**メリット:**
- 追加依存なし（macOS 標準 API）
- 導入・実装が容易
- オンデバイス認識でプライバシー保護
- リアルタイム認識のネイティブサポート
- App Sandbox 完全対応

**デメリット:**
- オンデバイス認識の精度が Whisper 系より劣る
- サーバーベース認識には時間・リクエスト数制限がある
- Apple の API 変更（SpeechAnalyzer への移行）の影響を受ける可能性
- 認識精度のカスタマイズ性が限定的

### 推奨

VoiceInput は「デフォルトの入力手段」としての高精度が求められるため、**SFSpeechRecognizer 単体ではオンデバイス認識の精度が不足する可能性がある**。以下の戦略を推奨:

1. **PoC で実際の日本語認識精度を計測**して判断する
2. 精度が不足する場合は **whisper.cpp または MLX Whisper をメインエンジン**とする
3. SFSpeechRecognizer は**フォールバックまたは軽量モード**として利用
4. macOS 26 対応時期に **SpeechAnalyzer への移行**を計画する

---

## 参考リンク

- [SFSpeechRecognizer | Apple Developer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognizer)
- [Recognizing Speech in Live Audio | Apple Developer Documentation](https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio)
- [supportsOnDeviceRecognition | Apple Developer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [requiresOnDeviceRecognition | Apple Developer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Asking Permission to Use Speech Recognition | Apple Developer Documentation](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition)
- [Bring advanced speech-to-text to your app with SpeechAnalyzer - WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Customize on-device speech recognition - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10101/)
- [Advances in Speech Recognition - WWDC19](https://developer.apple.com/videos/play/wwdc2019/256/)
- [Apple SpeechAnalyzer and Argmax WhisperKit](https://www.argmaxinc.com/blog/apple-and-argmax)
- [Apple's New Transcription APIs Blow Past Whisper in Speed Tests - MacRumors](https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/)
- [Hands-On: How Apple's New Speech APIs Outpace Whisper - MacStories](https://www.macstories.net/stories/hands-on-how-apples-new-speech-apis-outpace-whisper-for-lightning-fast-transcription/)
- [Available Languages in On-device Speech Recognition - Toru Furuya](https://medium.com/@toru_furuya/available-languages-in-on-device-speech-recognition-on-ios-in-2022-8c6383fac9f2)
- [SFSpeechRecognizer on MacOS - Apple Developer Forums](https://developer.apple.com/forums/thread/702323)
- [SFSpeechRecognizer limitations - Apple Developer Forums](https://developer.apple.com/forums/thread/125523)
