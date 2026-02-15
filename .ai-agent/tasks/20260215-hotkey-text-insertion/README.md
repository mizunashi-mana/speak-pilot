# ホットキー・テキスト挿入

## 目的・ゴール

グローバルホットキーで音声入力を開始・停止し、認識結果をフォーカス中のアプリにテキスト挿入する機能を実装する。

## 依存タスク

なし（独立して実装可能）

## 実装方針

### ファイル構成

```
Sources/VoiceInput/
  Hotkey/
    HotkeyManager.swift       # グローバルホットキー
  TextInsertion/
    TextInserter.swift        # テキスト挿入
```

### HotkeyManager.swift

- Carbon `RegisterEventHotKey` を使用
- デフォルトキー: **Ctrl+Option+Space**（Spotlight やキーボード入力切替と競合しない組み合わせ）
- `onToggle` コールバックで AppState に通知
- static instance パターンで C 関数ポインタコールバックに対応

### TextInserter.swift

- **NSPasteboard + CGEvent (Cmd+V)** 方式
- 手順:
  1. 現在のクリップボード内容を退避
  2. テキストをクリップボードに設定
  3. Cmd+V キーイベントをシミュレート
  4. 短い遅延後にクリップボードを復元
- Accessibility 権限が必要
  - `AXIsProcessTrustedWithOptions` で権限チェック・プロンプト表示
  - 権限がない場合は UI でガイダンスを表示

## 完了条件

- [ ] グローバルホットキーがどのアプリがフォーカスされていても動作する
- [ ] テキスト挿入で日本語テキストが正しく挿入される
- [ ] Accessibility 権限が未付与の場合に適切なガイダンスが表示される
- [ ] `swift build` でコンパイルエラーなし

## 作業ログ

- 2026-02-15: タスク作成
