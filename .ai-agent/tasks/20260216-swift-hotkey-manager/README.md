# Swift グローバルホットキー

## 目的

Carbon API (`RegisterEventHotKey`) を使ったグローバルホットキー（Ctrl+Option+Space）を実装する。メニューバーアプリからどのアプリがフォーカスされていてもホットキーを受け取れるようにする。

## 実装方針

- `@Observable` + `@MainActor` で UI 連携可能な状態管理
- Carbon `RegisterEventHotKey` / `InstallEventHandler` を使用
- C コールバックから `@MainActor` へのブリッジに `nonisolated(unsafe) static var` パターンを使用
- Accessibility 権限不要

## 完了条件

- [x] `HotkeyManager.swift` が実装されている
- [x] ユニットテストがパスする
- [x] `swift build` が成功する
- [x] `swift test` が成功する (32 tests passed)

## 作業ログ

- 2026-02-16: タスク開始
- 2026-02-16: HotkeyManager.swift 実装完了
  - Carbon `RegisterEventHotKey` / `InstallEventHandler` による Ctrl+Option+Space 登録
  - `nonisolated(unsafe) static var` パターンで C コールバック → `@MainActor` ブリッジ
  - `GetEventParameter` でホットキー ID を検証してからコールバック発火
  - `register()` / `unregister()` / `onToggle` コールバック / `isRegistered` 状態
- 2026-02-16: HotkeyManagerTests.swift 作成 (5テスト)
  - 初期状態、未登録 unregister、コールバック発火、コールバック置換、nil 化
- 2026-02-16: swift build / swift test 全パス確認 (32 tests)
