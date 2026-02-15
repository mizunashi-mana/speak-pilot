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
│       ├── AppState.swift              # アプリ状態管理（@Observable）[計画中]
│       ├── Backend/                    # Python バックエンド連携 [計画中]
│       │   ├── BackendProtocol.swift   # JSON プロトコル Codable 型
│       │   ├── ProcessRunner.swift     # Process + Pipe 非同期ラッパー
│       │   └── BackendManager.swift    # Python プロセスライフサイクル管理
│       ├── Hotkey/                     # グローバルホットキー [計画中]
│       │   └── HotkeyManager.swift     # Carbon RegisterEventHotKey
│       └── TextInsertion/             # テキスト挿入 [計画中]
│           └── TextInserter.swift      # NSPasteboard + CGEvent
├── backend/                            # Python バックエンドサービス [計画中]
│   ├── pyproject.toml                 # uv プロジェクト定義
│   └── speak_pilot_backend/
│       ├── __init__.py
│       ├── __main__.py                # エントリポイント
│       ├── service.py                 # JSON lines サービスループ
│       ├── audio.py                   # sounddevice ラッパー
│       ├── vad.py                     # Silero VAD ラッパー
│       └── transcriber.py            # MLX Whisper ラッパー
├── Tests/
│   └── VoiceInputTests/               # ユニットテスト
│       └── VoiceInputTests.swift
├── poc/                                # PoC（Phase 1 完了後に削除予定）
│   ├── swift/                          # Swift PoC
│   │   ├── Package.swift              # PoC 用 SPM 定義
│   │   └── Sources/
│   │       ├── whisperkit-realtime/   # WhisperKit リアルタイム書き起こし
│   │       └── apple-speech-realtime/ # Apple Speech リアルタイム書き起こし
│   └── python/                         # Python PoC（採用エンジン検証）
│       ├── pyproject.toml             # uv プロジェクト定義
│       ├── realtime_mlx_whisper.py    # Silero VAD + MLX Whisper（採用）
│       ├── realtime_faster_whisper.py # faster-whisper（参考実装）
│       └── tests/                     # 書き起こしテスト
│           ├── test_transcription.py  # 単体テスト（VAD + Whisper）
│           ├── test_realtime_stream.py # ストリームシミュレーション
│           └── fixtures/              # テスト用音声ファイル
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
│       ├── autodev-review-pr/          # PR コードレビュー
│       ├── autodev-start-new-project/  # 長期プロジェクト開始
│       ├── autodev-start-new-survey/   # 技術調査開始
│       ├── autodev-start-new-task/     # 個別タスク開始
│       └── autodev-steering/           # Steering ドキュメント更新
└── CLAUDE.md                           # Claude Code 向けプロジェクト説明
```

## 各ディレクトリの役割

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
