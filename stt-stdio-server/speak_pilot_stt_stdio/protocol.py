"""JSON lines protocol types for STT stdio server."""

from __future__ import annotations

import json
import logging
import sys
from dataclasses import dataclass
from typing import Literal

logger = logging.getLogger(__name__)

# --- Commands (stdin -> server) ---

CommandType = Literal["start", "stop", "shutdown"]


@dataclass(frozen=True, slots=True)
class Command:
    type: CommandType


_VALID_COMMAND_TYPES: set[str] = {"start", "stop", "shutdown"}


def parse_command(line: str) -> Command | None:
    """Parse a JSON line into a Command. Returns None on invalid input."""
    line = line.strip()
    if not line:
        return None
    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        logger.warning("Invalid JSON: %s", line)
        return None
    if not isinstance(data, dict):
        logger.warning("Expected JSON object: %s", line)
        return None
    cmd_type = data.get("type")
    if cmd_type not in _VALID_COMMAND_TYPES:
        logger.warning("Unknown command type: %s", cmd_type)
        return None
    return Command(type=cmd_type)


# --- Events (server -> stdout) ---

EventType = Literal[
    "ready", "speech_started", "transcription", "speech_ended", "error"
]


@dataclass(frozen=True, slots=True)
class ReadyEvent:
    type: Literal["ready"] = "ready"


@dataclass(frozen=True, slots=True)
class SpeechStartedEvent:
    type: Literal["speech_started"] = "speech_started"


@dataclass(frozen=True, slots=True)
class TranscriptionEvent:
    text: str
    is_final: bool
    type: Literal["transcription"] = "transcription"


@dataclass(frozen=True, slots=True)
class SpeechEndedEvent:
    type: Literal["speech_ended"] = "speech_ended"


@dataclass(frozen=True, slots=True)
class ErrorEvent:
    message: str
    type: Literal["error"] = "error"


Event = ReadyEvent | SpeechStartedEvent | TranscriptionEvent | SpeechEndedEvent | ErrorEvent

_stdout_lock = __import__("threading").Lock()


def emit_event(event: Event) -> None:
    """Serialize event to JSON and write to stdout with flush."""
    from dataclasses import asdict

    data = asdict(event)
    line = json.dumps(data, ensure_ascii=False)
    with _stdout_lock:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
