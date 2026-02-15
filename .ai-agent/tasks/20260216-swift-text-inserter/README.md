# Swift テキスト挿入

## 目的

認識されたテキストをフォーカス中のアプリケーションに挿入する。NSPasteboard + CGEvent (Cmd+V シミュレーション) 方式で、日本語/Unicode テキストに最も確実な方法を採用する。

## 実装方針

- `@Observable` + `@MainActor` で UI 連携可能な状態管理
- `AXIsProcessTrustedWithOptions` で Accessibility 権限チェック
- NSPasteboard の内容を退避 → テキスト設定 → Cmd+V シミュレーション → 復元
- CGEvent でキーストロークをシミュレーション

## 完了条件

- [x] `TextInserter.swift` が実装されている
- [x] ユニットテストがパスする
- [x] `swift build` が成功する
- [x] `swift test` が成功する (35 tests passed)

## 作業ログ

- 2026-02-16: タスク開始
- 2026-02-16: TextInserter.swift 実装完了
  - `AXIsProcessTrustedWithOptions` による Accessibility 権限チェック（文字列リテラルで Swift 6 concurrency 対応）
  - NSPasteboard 全アイテム・全タイプの退避・復元
  - CGEvent で Cmd+V キーストロークシミュレーション
  - `insertText()` / `checkAccessibility()` / `isAccessibilityGranted` 状態
- 2026-02-16: TextInserterTests.swift 作成 (3テスト)
  - 初期状態、権限なしエラー、checkAccessibility 呼び出し
- 2026-02-16: swift build / swift test 全パス確認 (35 tests)
