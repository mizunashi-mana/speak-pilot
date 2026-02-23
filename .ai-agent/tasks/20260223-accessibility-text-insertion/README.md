# Accessibility API によるテキスト挿入

## GitHub Issue

https://github.com/mizunashi-mana/speak-pilot/issues/17

## 目的・ゴール

音声認識で得られたテキストを、Accessibility API を使ってフォーカス中の入力フィールドに直接挿入する機能を実装する。現在のクリップボード経由（NSPasteboard + Cmd+V）の方式を改善し、クリップボード内容を上書きしない方式を実現する。

## 現状

- `TextInserter.swift`: NSPasteboard + CGEvent (Cmd+V) による挿入が実装済み
- `AppState.handleFinalTranscription`: 最終文字起こし → 挿入のフロー接続済み
- クリップボード退避・復元の仕組みあり

## 実装方針

Accessibility API (`AXUIElement`) を使ったテキスト挿入を主方式とし、対応できない場合は現行のクリップボード方式にフォールバックする。

1. `AXUIElementCreateSystemWide()` でシステムワイドのアクセシビリティ要素を取得
2. `kAXFocusedUIElementAttribute` でフォーカス中の要素を取得
3. フォーカス中の要素が `AXTextField` / `AXTextArea` 等のテキスト入力可能な要素かチェック
4. `kAXSelectedTextAttribute` の設定（選択範囲の置換 = カーソル位置への挿入）でテキストを挿入
5. Accessibility API での挿入が失敗した場合、現行のクリップボード方式にフォールバック

## 完了条件

- [x] Accessibility API によるテキスト挿入が動作する
- [x] Accessibility API 非対応の場合にクリップボード方式にフォールバックする
- [x] 既存のテストが通る（全 43 テスト pass）
- [ ] E2E で動作確認済み

## 作業ログ

### 2026-02-23

- `TextInserter.swift` を改修:
  - `insertTextViaAccessibility(_:)` を追加: `AXUIElementCreateSystemWide()` → `kAXFocusedUIElementAttribute` → `kAXSelectedTextAttribute` の設定でカーソル位置にテキスト挿入
  - `insertText(_:)` を改修: Accessibility API を先に試行し、失敗時にクリップボード方式にフォールバック
  - クリップボード方式を `insertTextViaClipboard(_:)` に分離
- `swift build` / `swift test` で全 43 テスト pass 確認
