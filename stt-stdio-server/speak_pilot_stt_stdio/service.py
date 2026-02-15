"""Main service loop for the STT stdio server."""

from __future__ import annotations

import logging
import sys
import threading

from .audio import AudioCapture
from .protocol import (
    Command,
    ErrorEvent,
    ReadyEvent,
    SpeechEndedEvent,
    SpeechStartedEvent,
    TranscriptionEvent,
    emit_event,
    parse_command,
)
from .transcriber import Transcriber
from .vad import VadEvent, VadProcessor

logger = logging.getLogger(__name__)


class Service:
    """STT service coordinating audio capture, VAD, and transcription."""

    def __init__(self) -> None:
        self._audio = AudioCapture()
        self._vad = VadProcessor()
        self._transcriber = Transcriber()
        self._shutdown_event = threading.Event()
        self._listening_event = threading.Event()

    def run(self) -> None:
        """Main service loop."""
        emit_event(ReadyEvent())
        logger.info("Service ready")

        cmd_thread = threading.Thread(target=self._read_commands, daemon=True)
        cmd_thread.start()

        try:
            while not self._shutdown_event.is_set():
                if not self._listening_event.is_set():
                    self._listening_event.wait(timeout=0.05)
                    continue

                frame = self._audio.read_frame(timeout=0.1)
                if frame is None:
                    continue

                try:
                    event, utterance = self._vad.process_frame(frame)
                except Exception:
                    logger.exception("VAD processing error")
                    emit_event(ErrorEvent(message="VAD processing error"))
                    continue

                if event == VadEvent.SPEECH_START:
                    emit_event(SpeechStartedEvent())
                elif event == VadEvent.SPEECH_END:
                    emit_event(SpeechEndedEvent())
                    if utterance is not None:
                        self._transcriber.transcribe_async(
                            utterance, self._on_transcription
                        )
        except Exception:
            logger.exception("Service loop error")
            emit_event(ErrorEvent(message="Service loop error"))
        finally:
            self._stop_listening()
            logger.info("Service stopped")

    def _read_commands(self) -> None:
        """Read commands from stdin (runs in a separate thread)."""
        try:
            for line in sys.stdin:
                cmd = parse_command(line)
                if cmd is not None:
                    self._handle_command(cmd)
                if self._shutdown_event.is_set():
                    break
        except Exception:
            logger.exception("Command reader error")
        finally:
            # stdin closed or error → shutdown
            self._shutdown_event.set()

    def _handle_command(self, cmd: Command) -> None:
        logger.info("Command: %s", cmd.type)
        if cmd.type == "start":
            self._start_listening()
        elif cmd.type == "stop":
            self._stop_listening()
        elif cmd.type == "shutdown":
            self._stop_listening()
            self._shutdown_event.set()

    def _start_listening(self) -> None:
        if self._listening_event.is_set():
            return
        try:
            self._audio.start()
            self._listening_event.set()
            logger.info("Listening started")
        except Exception:
            logger.exception("Failed to start audio capture")
            emit_event(ErrorEvent(message="Failed to start audio capture"))

    def _stop_listening(self) -> None:
        if not self._listening_event.is_set():
            return
        self._listening_event.clear()
        self._audio.stop()
        self._vad.reset()
        logger.info("Listening stopped")

    def _on_transcription(self, text: str, is_final: bool) -> None:
        emit_event(TranscriptionEvent(text=text, is_final=is_final))
