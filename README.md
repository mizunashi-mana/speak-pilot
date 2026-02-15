# SpeakPilot

Voice-first input for macOS. Speak, and let your words land anywhere.

## Overview

SpeakPilot は、音声入力をデフォルトの入力インターフェースにする macOS ネイティブアプリです。ホットキーひとつで音声入力を開始し、任意のアプリケーションにテキストを挿入できます。

音声認識はすべてローカルで処理されるため、クラウドへのデータ送信は不要です。

## Features

- **グローバル音声入力** — どのアプリでも、ホットキーで即座に音声入力を開始・停止
- **ローカル音声認識** — Silero VAD + MLX Whisper によるオンデバイス処理
- **リアルタイム文字起こし** — 話しながらテキストが表示される
- **プライバシー重視** — 音声データは端末から一切外に出ない

## Requirements

- macOS 14 Sonoma 以降
- Apple Silicon Mac

## Tech Stack

- Swift / SwiftUI (UI・システム統合)
- Python / MLX Whisper + Silero VAD (音声認識バックエンド)
- サブプロセス + stdin/stdout JSON lines (IPC)

## License

TBD
