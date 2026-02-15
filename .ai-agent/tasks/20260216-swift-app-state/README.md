# Swift アプリ状態管理

## 目的

BackendManager / HotkeyManager / TextInserter を統合し、アプリ全体のライフサイクルを管理する `AppState` を実装する。

## 実装方針

- `@Observable` + `@MainActor` で UI 連携可能な状態管理
- 3 つのマネージャを保持・連携
- 統一状態を UI に公開（idle / starting / ready / listening / error）
- ホットキー → トグル → 最終文字起こし → テキスト挿入のフロー
- BackendManager に `onFinalTranscription` コールバック追加

## 完了条件

- [x] `AppState.swift` が実装されている
- [x] `BackendManager` に `onFinalTranscription` コールバックが追加されている
- [x] ユニットテストがパスする
- [x] `swift build` が成功する
- [x] `swift test` が成功する (41 tests passed)

## 作業ログ

- 2026-02-16: タスク開始
- 2026-02-16: AppState.swift 実装完了
  - 統一状態管理（idle / starting / ready / listening / error）
  - `setup()` / `toggleListening()` / `shutdown()` API
  - HotkeyManager.onToggle → toggleListening() のコールバック接続
  - BackendManager.onFinalTranscription → TextInserter.insertText() のコールバック接続
  - トリミング済みテキストのみ挿入、Accessibility 未許可時はスキップ
- 2026-02-16: BackendManager に onFinalTranscription コールバック追加
- 2026-02-16: AppStateTests.swift 作成 (6 テスト)
  - 初期状態、idle での toggleListening、idle での shutdown
  - マネージャ注入確認、コールバック接続確認（hotkey / transcription）
- 2026-02-16: swift build / swift test 全パス確認 (41 tests)
