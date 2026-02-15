# Swift Backend Protocol

## 目的・ゴール

Python STT サーバ (`stt-stdio-server/`) との JSON lines プロトコルに対応する Swift 側の Codable 型を定義する。`BackendCommand`（Swift → Python）と `BackendEvent`（Python → Swift）の型安全なシリアライズ/デシリアライズを提供する。

## 依存タスク

- [x] Python STT サーバ (`stt-stdio-server/`): JSON lines プロトコル定義済み

## 実装方針

### ファイル構成

```
Sources/VoiceInput/Backend/
  BackendProtocol.swift   # BackendCommand / BackendEvent の Codable 定義
Tests/VoiceInputTests/
  BackendProtocolTests.swift  # エンコード/デコードテスト
```

### 型定義

- **BackendCommand** (enum, Encodable): start / stop / shutdown
- **BackendEvent** (enum, Decodable): ready / speechStarted / transcription / speechEnded / error

### JSON マッピング

Python 側の snake_case キーに合わせる（`is_final` → `isFinal`, `speech_started` → `speechStarted` など）。

## 完了条件

- [x] BackendCommand が正しい JSON にエンコードされる
- [x] BackendEvent が Python 側の JSON を正しくデコードできる
- [x] ユニットテストが通る（11テスト全合格）

## 作業ログ

- 2026-02-15: タスク作成
- 2026-02-15: 実装完了、全テスト合格
