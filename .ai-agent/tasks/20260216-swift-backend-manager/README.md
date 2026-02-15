# Swift バックエンドマネージャ

## 目的

Python STT サーバのライフサイクルを管理する `BackendManager` を実装する。`ProcessRunner` の上位レイヤーとして、プロセスの起動・停止・異常終了時の処理を担当する。

## 実装方針

- `@Observable` + `@MainActor` でUI連携可能な状態管理
- `ProcessRunner` を内部に保持し、直接公開しない
- 状態: idle / starting / ready / listening / error
- プロセス異常終了時の状態リセット
- ログは os.Logger に転送

## 完了条件

- [x] `BackendManager.swift` が実装されている
- [x] ユニットテストがパスする
- [x] `swift build` が成功する
- [x] `swift test` が成功する (25 tests passed)

## 作業ログ

- 2026-02-16: タスク開始
- 2026-02-16: BackendManager.swift 実装完了
  - `@Observable` + `@MainActor` による状態管理
  - `BackendCommandResolver` プロトコルでテスト時にmockサーバを注入可能に
  - 状態: idle → starting → ready ⇄ listening, error
  - イベント処理・ログ転送・異常終了ハンドリング
- 2026-02-16: BackendManagerTests.swift 作成 (8テスト)
  - launch → ready 遷移、start/stop listening、transcription受信、shutdown、エッジケース
- 2026-02-16: swift build / swift test 全パス確認
