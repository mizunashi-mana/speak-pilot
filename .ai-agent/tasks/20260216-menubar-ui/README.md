# メニューバー UI

## 目的

メニューバーアプリの UI を実装し、AppState と連携して状態表示・操作・リアルタイム文字起こし表示・エラー表示を行う。

## 実装方針

- `VoiceInputApp.swift`: AppState を `@State` で保持、状態に応じたアイコン変更、ライフサイクル管理
- `ContentView.swift`: 状態表示、トグルボタン、リアルタイム文字起こし、エラー表示、終了ボタン
- メニューバーアイコン: idle=mic, starting=mic.badge.ellipsis, ready=mic, listening=mic.fill, error=mic.slash

## 完了条件

- [x] `VoiceInputApp` が `AppState` と連携している
- [x] 状態に応じたメニューバーアイコン変化
- [x] 状態表示・トグル・文字起こし表示・エラー表示が動作
- [x] `swift build` が成功する

## 作業ログ

- 2026-02-16: タスク開始
- 2026-02-16: 実装完了
  - VoiceInputApp: AppState を @State で保持、menuBarIcon で状態に応じたアイコン切替
  - ContentView: 4 セクション構成（状態表示/文字起こし/操作ボタン/フッター）
    - 状態インジケーター（色付き Circle + テキスト）
    - リアルタイム文字起こし表示（listening 中または結果があるとき）
    - 状態に応じた操作ボタン（starting: ProgressView, ready: 録音開始, listening: 録音停止, error: エラーメッセージ + 再試行）
    - フッター: Accessibility 警告、ホットキーヒント、終了ボタン
  - .task で appState.setup() を呼び出しライフサイクル管理
  - swift build / swift test 全 41 テストパス
