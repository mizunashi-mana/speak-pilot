# SpeakPilot ディレクトリ構成

## 概要

macOS 音声入力アプリ「SpeakPilot」のプロジェクト。Swift Package Manager ベースで構成。Python バックエンド（Silero VAD + MLX Whisper）をサブプロセスとして起動し、stdin/stdout JSON lines プロトコルで通信する。

## ディレクトリ構造

```
speak-pilot/
├── Package.swift                       # SPM パッケージ定義（macOS 14+）
├── Sources/
│   └── VoiceInput/                     # メインアプリターゲット
│       ├── VoiceInputApp.swift         # @main エントリポイント（MenuBarExtra）
│       ├── ContentView.swift           # メニューバーポップオーバー UI
│       ├── AppState.swift              # アプリ状態管理（@Observable）
│       ├── Info.plist                  # アプリ情報（マイク使用許可等）
│       ├── Backend/                    # Python バックエンド連携
│       │   ├── BackendProtocol.swift   # JSON プロトコル Codable 型
│       │   ├── ProcessRunner.swift     # Process + Pipe 非同期ラッパー
│       │   └── BackendManager.swift    # Python プロセスライフサイクル管理
│       ├── Hotkey/                     # グローバルホットキー
│       │   └── HotkeyManager.swift     # Carbon RegisterEventHotKey
│       └── TextInsertion/             # テキスト挿入
│           └── TextInserter.swift      # NSPasteboard + CGEvent
├── Tests/
│   └── VoiceInputTests/               # ユニットテスト（Swift Testing）
│       ├── VoiceInputTests.swift
│       ├── BackendProtocolTests.swift  # JSON プロトコルのシリアライズ検証
│       ├── ProcessRunnerTests.swift    # プロセス起動・通信テスト
│       ├── BackendManagerTests.swift   # バックエンド管理テスト
│       ├── HotkeyManagerTests.swift    # ホットキー管理テスト
│       ├── TextInserterTests.swift     # テキスト挿入テスト
│       ├── AppStateTests.swift         # アプリ状態テスト
│       └── Fixtures/
│           └── echo_server.py          # テスト用モック Python サーバ
├── stt-stdio-server/                   # Python STT サーバ (stdin/stdout JSON lines)
│   ├── pyproject.toml                 # uv プロジェクト定義
│   └── speak_pilot_stt_stdio/
│       ├── __init__.py
│       ├── __main__.py                # エントリポイント: python -m speak_pilot_stt_stdio
│       ├── protocol.py                # JSON lines プロトコル型定義
│       ├── service.py                 # メインサービスループ
│       ├── audio.py                   # sounddevice ラッパー
│       ├── vad.py                     # Silero VAD ラッパー
│       └── transcriber.py            # MLX Whisper ラッパー
├── .github/                            # GitHub 設定
│   ├── workflows/
│   │   ├── ci-build.yml               # ビルド CI
│   │   └── ci-test.yml                # テスト CI
│   ├── actions/
│   │   └── setup-swift/
│   │       └── action.yml             # Swift 環境セットアップ
│   └── dependabot.yml                 # 依存関係自動更新
├── .ai-agent/                          # AI エージェント向けドキュメント
│   ├── steering/                       # 戦略的ガイドドキュメント
│   │   ├── market.md                   # 市場分析・競合調査
│   │   ├── product.md                  # プロダクトビジョン・戦略
│   │   ├── tech.md                     # 技術アーキテクチャ・スタック
│   │   ├── plan.md                     # 実装計画・ロードマップ
│   │   └── work.md                     # 開発ワークフロー・規約
│   ├── structure.md                    # このファイル（ディレクトリ構成の説明）
│   ├── projects/                       # 長期プロジェクト管理
│   ├── tasks/                          # 個別タスク管理
│   └── surveys/                        # 技術調査・検討
├── .claude/                            # Claude Code 設定
│   └── skills/                         # autodev スキル定義
│       ├── autodev-create-issue/       # GitHub Issue 作成
│       ├── autodev-create-pr/          # PR 作成
│       ├── autodev-discussion/         # 対話的アイデア整理
│       ├── autodev-import-review-suggestions/  # PR レビュー取り込み
│       ├── autodev-replan/             # ロードマップ再策定
│       ├── autodev-review-pr/          # PR コードレビュー（マルチエージェント）
│       ├── autodev-start-new-project/  # 長期プロジェクト開始
│       ├── autodev-start-new-survey/   # 技術調査開始
│       ├── autodev-start-new-task/     # 個別タスク開始
│       ├── autodev-steering/           # Steering ドキュメント更新
│       └── autodev-switch-to-default/  # デフォルトブランチ切り替え
├── LICENSE                             # デュアルライセンス概要
├── LICENSE.Apache-2.0.txt             # Apache License 2.0 全文
├── LICENSE.MPL-2.0.txt                # Mozilla Public License 2.0 全文
├── devenv.nix                          # Nix 開発環境定義
├── devenv.yaml                         # devenv 設定
├── devenv.lock                         # devenv ロックファイル
├── CLAUDE.md                           # Claude Code 向けプロジェクト説明
└── README.md                           # プロジェクト README
```

## 各ディレクトリの役割

### Sources/VoiceInput/

メインアプリケーションの Swift コード。以下のモジュール構成:

- **ルート**: アプリエントリポイント（`VoiceInputApp.swift`）、UI（`ContentView.swift`）、状態管理（`AppState.swift`）
- **Backend/**: Python サブプロセスとの連携層。JSON lines プロトコルの型定義、プロセスの非同期ラッパー、ライフサイクル管理
- **Hotkey/**: Carbon API によるグローバルホットキー（Ctrl+Option+Space）
- **TextInsertion/**: NSPasteboard + CGEvent によるテキスト挿入

### Tests/VoiceInputTests/

Swift Testing フレームワークによるユニットテスト。各モジュールに対応するテストファイルと、テスト用モック Python サーバ（`Fixtures/echo_server.py`）を含む。

### stt-stdio-server/

Python STT（Speech-to-Text）バックエンドサーバ。uv プロジェクトとして管理。stdin/stdout JSON lines プロトコルで Swift アプリと通信する。

### .ai-agent/steering/

プロジェクトの戦略・方針を定めるドキュメント群。タスクに着手する前に関連ドキュメントを確認する。

### .ai-agent/projects/

複数タスクにまたがる長期的な目標を管理する。`YYYYMMDD-{プロジェクト名}/README.md` の形式で作成。

### .ai-agent/tasks/

日〜週単位の個別タスクを管理する。`YYYYMMDD-{タスク名}/README.md` の形式で作成。

### .ai-agent/surveys/

技術調査・検討の結果を記録する。`YYYYMMDD-{調査名}/README.md` の形式で作成。

### .claude/skills/

Claude Code の autodev スキル定義。各スキルは `SKILL.md` に手順とルールを記述。

### .github/

GitHub Actions CI ワークフロー（ビルド・テスト）と Dependabot 設定。
