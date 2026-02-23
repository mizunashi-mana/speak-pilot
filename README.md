# SpeakPilot

Voice-first input for macOS. Speak, and let your words land anywhere.

## What & Why

SpeakPilot is a native macOS app that turns voice into the default input interface. With a single hotkey, start speaking and have your words inserted into any application — no cloud, no subscription.

All speech recognition runs locally on your Apple Silicon Mac using Silero VAD + MLX Whisper, so your voice data never leaves your device.

## Features

- **Global voice input** — Start/stop dictation instantly with a hotkey, in any app
- **Local speech recognition** — On-device processing with Silero VAD + MLX Whisper
- **Real-time transcription** — See text appear as you speak
- **Privacy-first** — Zero data sent to the cloud

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon Mac (M1 or later)

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/) with [devenv](https://devenv.sh/) (recommended) or manually install Swift toolchain and Python with uv

### Build & Run

```bash
# Enter development environment
devenv shell

# Build the Swift app
swift build

# Run the STT backend independently (for testing)
uv run --project stt-stdio-server/ python -m speak_pilot_stt_stdio
```

### Run Tests

```bash
# Swift tests
swift test

# Python STT server tests
uv run --project stt-stdio-server/ python -m pytest
```

## Tech Stack

- **Swift / SwiftUI** — UI and macOS system integration
- **Python / MLX Whisper + Silero VAD** — Speech recognition backend
- **Subprocess + stdin/stdout JSON lines** — IPC between Swift and Python

## License

Licensed under either of [Apache License, Version 2.0](LICENSE.Apache-2.0.txt) or [Mozilla Public License, Version 2.0](LICENSE.MPL-2.0.txt) at your option.
