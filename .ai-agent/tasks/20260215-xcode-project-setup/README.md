# Xcode プロジェクト初期セットアップ

## 目的・ゴール

macOS 音声入力アプリ「VoiceInput」の Xcode プロジェクトを作成し、ビルド可能な状態を確立する。

## 実装方針

1. Swift Package Manager ベースのプロジェクトを作成（.xcodeproj なし）
2. SwiftUI ベースのメニューバーアプリとして構成（MenuBarExtra）
3. macOS 14 Sonoma 以降をターゲット
4. 基本的なアプリ構造（App, ContentView）を作成
5. ユニットテストターゲットを含める（Swift Testing）

## 完了条件

- [x] Swift Package が作成されている
- [x] `swift build` でビルドが成功する
- [x] MenuBarExtra によるメニューバーアプリとして構成されている
- [x] ユニットテストターゲットが存在し、`swift test` でテストが実行できる
- [x] structure.md が更新されている

## 作業ログ

- 2026-02-15: Package.swift, VoiceInputApp.swift, ContentView.swift, VoiceInputTests.swift を作成
- 2026-02-15: `swift build` ビルド成功、`swift test` テスト 1 件パス
- 2026-02-15: structure.md を更新
