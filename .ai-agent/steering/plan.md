# 実装計画

## 現在のフェーズ

**Phase 1: 基本機能実装**

## フェーズ計画

### Phase 0: 基盤構築・PoC（完了）

音声認識の実現可能性を検証し、プロジェクトの技術基盤を確立する。

- [x] Xcode プロジェクトの初期セットアップ
- [x] 音声認識エンジンの PoC（MLX Whisper / Apple Speech の比較検証）
- [x] マイク入力のキャプチャと音声認識パイプラインの構築
- [x] 認識結果の精度・レイテンシ評価
- [x] 採用エンジン決定: **Silero VAD + MLX Whisper** (large-v3-turbo)

### Phase 1: 基本機能実装（現在）

最小限の音声入力機能を動作させる。Swift メニューバーアプリから Python バックエンド（Silero VAD + MLX Whisper）をサブプロセスとして起動し、音声認識結果をフォーカス中のアプリに挿入する。

#### 決定済み設計

- **IPC 方式**: サブプロセス + stdin/stdout (JSON lines プロトコル)
- **音声キャプチャ**: Python 側 (sounddevice)
- **テキスト挿入**: NSPasteboard + CGEvent (Cmd+V シミュレーション)
- **ホットキー**: Carbon RegisterEventHotKey (Ctrl+Option+Space)

#### タスク一覧

- [x] Python STT サーバ (`stt-stdio-server/`): PoC をサービス化、JSON lines プロトコル実装
- [x] Swift バックエンドプロトコル型: BackendCommand / BackendEvent の Codable 定義
- [x] Swift プロセスランナー: Foundation.Process + Pipe の非同期ラッパー
- [ ] Swift バックエンドマネージャ: Python プロセスのライフサイクル管理
- [ ] グローバルホットキー: Carbon API による Ctrl+Option+Space トグル
- [ ] テキスト挿入: NSPasteboard + CGEvent、Accessibility 権限チェック
- [ ] アプリ状態管理: @Observable AppState（BackendManager / HotkeyManager / TextInserter 統合）
- [ ] メニューバー UI: 状態表示、開始/停止、リアルタイム文字起こし、エラー表示
- [ ] 統合・動作確認: エンドツーエンドで全機能を結合
- [ ] `poc/` ディレクトリの削除（本体統合完了後）

### Phase 2: システム統合・UX 改善

macOS との深い統合とユーザー体験の磨き込み。

- [ ] システム全体でのグローバル入力対応
- [ ] 入力コンテキストの最適化
- [ ] 設定画面の実装
- [ ] エラーハンドリング・フィードバック UI

### Phase 3: 高度な機能

差別化機能の実装。

- [ ] カスタム語彙・辞書登録
- [ ] 音声コマンド対応
- [ ] 声紋認識によるユーザー識別

## 完了済み機能

- Xcode / SPM プロジェクト初期セットアップ
- 音声認識エンジン PoC 完了・採用決定 (Silero VAD + MLX Whisper)

## 進行中の作業

- Phase 1: 基本機能実装（設計完了、実装準備中）
