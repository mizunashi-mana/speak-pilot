# voice-input ディレクトリ構成

## 概要

macOS 音声入力アプリ「VoiceInput」のプロジェクト。Swift Package Manager ベースで構成。

## ディレクトリ構造

```
voice-input/
├── Package.swift                       # SPM パッケージ定義（macOS 14+）
├── Sources/
│   └── VoiceInput/                     # メインアプリターゲット
│       ├── VoiceInputApp.swift         # @main エントリポイント（MenuBarExtra）
│       └── ContentView.swift           # メニューバーポップオーバー UI
├── Tests/
│   └── VoiceInputTests/               # ユニットテスト
│       └── VoiceInputTests.swift
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
