# Swift Process Runner

## 目的・ゴール

Python STT サーバをサブプロセスとして起動し、stdin/stdout/stderr の Pipe を介して JSON lines プロトコルで非同期通信するラッパーを提供する。

## 依存タスク

- [x] Python STT サーバ (`stt-stdio-server/`): JSON lines プロトコル定義済み
- [x] Swift バックエンドプロトコル型: BackendCommand / BackendEvent 定義済み

## 実装方針

### ファイル構成

```
Sources/VoiceInput/Backend/
  ProcessRunner.swift   # Foundation.Process + Pipe の非同期ラッパー
Tests/VoiceInputTests/
  ProcessRunnerTests.swift  # ユニットテスト
```

### 設計

- `ProcessRunner` actor: Foundation.Process のラッパー
- stdin 経由で `BackendCommand` を JSON line として送信
- stdout から `BackendEvent` を `AsyncStream` で受信
- stderr ログを `AsyncStream` で提供
- プロセス異常終了の検知

## 完了条件

- [x] ProcessRunner が Foundation.Process を起動・管理できる
- [x] stdin 経由で BackendCommand を送信できる
- [x] stdout から BackendEvent を AsyncStream で受信できる
- [x] stderr のログを取得できる
- [x] ビルドが通り、テストが合格する（17テスト全合格）

## 作業ログ

- 2026-02-15: タスク作成
- 2026-02-15: 実装完了、全テスト合格
