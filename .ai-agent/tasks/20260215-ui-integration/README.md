# UI・統合

## 目的・ゴール

全コンポーネント（BackendManager, HotkeyManager, TextInserter）を統合し、メニューバーアプリとして動作させる。

## 依存タスク

- [Swift バックエンド連携](../20260215-swift-backend-integration/)
- [ホットキー・テキスト挿入](../20260215-hotkey-text-insertion/)

## 実装方針

### ファイル構成

```
Sources/VoiceInput/
  VoiceInputApp.swift   # 更新: AppState 注入、動的アイコン
  ContentView.swift     # 更新: 実機能 UI
  AppState.swift        # 新規: 状態管理
```

### AppState.swift

- `@MainActor @Observable` クラス
- `RecognitionState`: idle / listening / speechDetected / transcribing
- BackendManager / HotkeyManager / TextInserter を保持
- `setup()`: バックエンド起動、ホットキー登録、コールバック設定
- `toggleRecognition()`: 状態に応じて start/stop
- `onTranscription`: final な結果 → TextInserter で挿入

### VoiceInputApp.swift

- `@State var appState = AppState()` を注入
- 動的メニューバーアイコン: mic (idle) / mic.fill (listening) / mic.slash (error)
- `MenuBarExtraStyle(.window)` でポップオーバー表示
- `@NSApplicationDelegateAdaptor` で Accessibility 権限チェック

### ContentView.swift

- 状態インジケータ（カラードット + テキスト）
- 開始/停止ボタン
- リアルタイム文字起こし表示
- エラーメッセージ表示
- 終了ボタン

### エンドツーエンド動作フロー

1. アプリ起動 → Python バックエンド起動 → ready 受信
2. ホットキー or ボタンで start コマンド送信
3. VAD が発話検出 → speech_started イベント → UI に反映
4. Whisper が書き起こし → transcription イベント → UI にリアルタイム表示
5. 発話終了 → speech_ended → is_final な結果 → TextInserter でテキスト挿入
6. ホットキー or ボタンで stop コマンド送信

## 完了条件

- [ ] アプリがメニューバーアプリとして起動できる
- [ ] ホットキーで音声入力の開始・停止ができる
- [ ] リアルタイムで文字起こしが表示される
- [ ] 認識結果がフォーカス中のアプリに挿入される
- [ ] エラー時に適切なフィードバックが表示される

## 作業ログ

- 2026-02-15: タスク作成
