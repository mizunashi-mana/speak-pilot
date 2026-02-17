# 統合・動作確認: エンドツーエンドで全機能を結合

## 目的

Phase 1 の全コンポーネント（Python STT サーバ、BackendManager、HotkeyManager、TextInserter、AppState、メニューバー UI）を結合し、エンドツーエンドで動作する状態にする。

## 実装方針

1. **バックエンド作業ディレクトリ修正**: 開発時・リリース時の両方で stt-stdio-server/ を正しく解決
2. **部分文字起こし転送**: BackendManager → AppState にリアルタイム文字起こしを伝搬
3. **Info.plist 設定**: NSMicrophoneUsageDescription を追加
4. **ビルド・テスト確認**: swift build / swift test パス

## 完了条件

- [x] バックエンド起動時に stt-stdio-server/ の絶対パスが正しく解決される
- [x] 部分文字起こしが ContentView にリアルタイム表示される
- [x] Info.plist に NSMicrophoneUsageDescription が設定されている
- [x] `swift build` が成功する
- [x] `swift test` が全パスする

## 作業ログ

- 2026-02-16: タスク開始
- 2026-02-16: 実装完了
  - DefaultBackendCommandResolver: 実行バイナリから親ディレクトリを辿って stt-stdio-server/ を検索する resolveProjectDirectory() を追加
  - FileManager.isDirectory(at:) ヘルパー追加
  - BackendManager: onPartialTranscription コールバック追加、部分文字起こし（is_final=false）を通知
  - AppState: wireUpCallbacks() で onPartialTranscription → currentTranscription 更新を接続
  - Info.plist: NSMicrophoneUsageDescription を追加、Package.swift で exclude 設定
  - テスト: partialTranscriptionCallbackIsWired / partialTranscriptionUpdatesCurrentTranscription 追加
  - swift build 成功、swift test 全 43 テストパス
