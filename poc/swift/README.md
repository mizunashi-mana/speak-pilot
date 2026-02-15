# Speech Recognition PoC

WhisperKit と Apple Speech Framework を使ったリアルタイム音声書き起こしの PoC です。

## 前提条件

- macOS 14 以上
- Xcode 16 以上（Swift 6.0）
- マイクへのアクセス権限

## ビルド

```bash
cd poc/swift
swift build
```

初回ビルド時は WhisperKit とその依存パッケージのダウンロードに時間がかかります。

## 実行

### WhisperKit リアルタイム書き起こし

```bash
swift run whisperkit-realtime
```

モデルを指定する場合:

```bash
swift run whisperkit-realtime large-v3
swift run whisperkit-realtime large-v3-turbo
swift run whisperkit-realtime base
```

デフォルトモデルは `large-v3-turbo` です。初回実行時はモデルのダウンロードが自動的に行われます（サイズはモデルにより異なります）。

利用可能なモデルは [WhisperKit のリポジトリ](https://github.com/argmaxinc/WhisperKit) を参照してください。

### Apple Speech Framework リアルタイム書き起こし

```bash
swift run apple-speech-realtime
```

Apple Speech Framework はモデルのダウンロードが不要で、すぐに利用を開始できます。

## 終了方法

どちらのツールも `Ctrl+C` で終了できます。

## 注意事項

- 初回実行時にマイクへのアクセス許可を求めるダイアログが表示されます。許可してください。
- Apple Speech Framework を使う場合、macOS のシステム設定で音声認識を許可する必要があります:
  - システム設定 > プライバシーとセキュリティ > 音声認識
  - ターミナルアプリ（または使用しているターミナルエミュレータ）を許可
- WhisperKit は初回実行時にモデルをダウンロードします。`large-v3-turbo` は約 1.5GB 程度のダウンロードが必要です。
- WhisperKit はオンデバイスで動作するため、ネットワーク接続は初回のモデルダウンロード時のみ必要です。
- Apple Speech Framework はオンデバイスとサーバーベースの認識を自動的に切り替えます。
- CLI ツールとして Sandbox 外で動作するため、Entitlements.plist は参考用として含めています。
