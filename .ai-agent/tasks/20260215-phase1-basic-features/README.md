# Phase 1: 基本機能実装

## 目的・ゴール

最小限の音声入力機能を動作させる。Swift メニューバーアプリから Python バックエンド（Silero VAD + MLX Whisper）をサブプロセスとして起動し、音声認識結果をフォーカス中のアプリに挿入する。

## 設計決定

- **IPC 方式**: サブプロセス + stdin/stdout (JSON lines プロトコル)
- **音声キャプチャ**: Python 側 (sounddevice)
- **テキスト挿入**: NSPasteboard + CGEvent (Cmd+V シミュレーション)
- **ホットキー**: Carbon RegisterEventHotKey (Ctrl+Option+Space)

## サブタスク

| # | タスク | 依存 | 状態 |
|---|--------|------|------|
| 1 | [Python バックエンドサービス](../20260215-python-backend-service/) | なし | 未着手 |
| 2 | [Swift バックエンド連携](../20260215-swift-backend-integration/) | #1 | 未着手 |
| 3 | [ホットキー・テキスト挿入](../20260215-hotkey-text-insertion/) | なし | 未着手 |
| 4 | [UI・統合](../20260215-ui-integration/) | #2, #3 | 未着手 |
| 5 | PoC ディレクトリ削除 | #4 | 未着手 |

## 完了条件

- [ ] Swift アプリから Python バックエンドの音声認識が動作する
- [ ] メニューバーアプリとして起動できる
- [ ] ホットキーで音声入力の開始・停止ができる
- [ ] 認識結果がフォーカス中のアプリに挿入される
- [ ] リアルタイムで文字起こしが表示される

## 作業ログ

- 2026-02-15: タスク開始、設計完了
