# Swift バックエンド連携

## 目的・ゴール

Swift アプリから Python バックエンドサブプロセスを管理し、JSON lines プロトコルで通信する基盤を構築する。

## 依存タスク

- [Python バックエンドサービス](../20260215-python-backend-service/)

## 実装方針

### ファイル構成

```
Sources/VoiceInput/Backend/
  BackendProtocol.swift   # JSON プロトコル Codable 型
  ProcessRunner.swift     # Process + Pipe の非同期ラッパー
  BackendManager.swift    # Python プロセスライフサイクル管理
```

### BackendProtocol.swift

- `BackendCommand` enum (Encodable): `.start`, `.stop`, `.shutdown`
- `BackendEvent` enum (Decodable): `.ready`, `.speechStarted`, `.speechEnded`, `.transcription(text:isFinal:)`, `.error(message:)`
- JSON `type` フィールドで判別する手動 Codable 実装

### ProcessRunner.swift

- `Foundation.Process` + `Pipe` で Python サブプロセスを管理
- `FileHandle.bytes` の `AsyncSequence` で stdout を行単位で非同期読み取り
- `writeLine(_:)` で stdin に書き込み
- stderr を `os.Logger` でデバッグログ出力
- プロセスの起動・終了・異常終了を管理

### BackendManager.swift

- `@MainActor @Observable` クラス
- `State`: idle → starting → ready → listening → error
- `launch()`: Python パス解決 → ProcessRunner 起動 → stdout 読み取り Task 開始
- `startRecognition()` / `stopRecognition()`: stdin にコマンド送信
- `shutdown()`: shutdown コマンド → タイムアウト付き待機 → 強制終了
- Python パス: 開発時は `uv run --project backend/ python -m speak_pilot_backend`

## 完了条件

- [ ] BackendProtocol の encode/decode ユニットテストがパスする
- [ ] BackendManager が Python バックエンドを起動・停止できる
- [ ] stdout からイベントを非同期に受信し、状態が正しく遷移する
- [ ] `swift build` でコンパイルエラーなし

## 作業ログ

- 2026-02-15: タスク作成
