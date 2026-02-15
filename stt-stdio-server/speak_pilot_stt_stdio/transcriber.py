"""MLX Whisper transcription wrapper with async execution."""

from __future__ import annotations

import logging
import threading
from typing import Callable

import numpy as np

logger = logging.getLogger(__name__)

DEFAULT_MODEL = "mlx-community/whisper-large-v3-turbo"


class Transcriber:
    """Wraps mlx_whisper.transcribe() with thread-based async execution."""

    def __init__(
        self,
        model: str = DEFAULT_MODEL,
        language: str = "ja",
    ):
        self._model = model
        self._language = language
        self._busy = False
        self._lock = threading.Lock()
        logger.info("Transcriber initialized (model=%s, language=%s)", model, language)

    @property
    def is_busy(self) -> bool:
        with self._lock:
            return self._busy

    def transcribe_async(
        self,
        audio: np.ndarray,
        callback: Callable[[str, bool], None],
    ) -> None:
        """Transcribe audio in a background thread.

        If a previous transcription is still running, this call is ignored.
        Results are delivered via callback(text, is_final).
        """
        with self._lock:
            if self._busy:
                logger.debug("Transcription skipped (busy)")
                return
            self._busy = True

        thread = threading.Thread(
            target=self._run,
            args=(audio, callback),
            daemon=True,
        )
        thread.start()

    def _run(
        self,
        audio: np.ndarray,
        callback: Callable[[str, bool], None],
    ) -> None:
        try:
            import mlx_whisper

            duration = len(audio) / 16000
            logger.info("Transcribing %.1fs of audio...", duration)
            result = mlx_whisper.transcribe(
                audio,
                path_or_hf_repo=self._model,
                language=self._language,
            )
            text = result.get("text", "").strip()
            if text:
                callback(text, True)
            else:
                logger.debug("Empty transcription result")
        except Exception:
            logger.exception("Transcription failed")
            from .protocol import ErrorEvent, emit_event

            emit_event(ErrorEvent(message="Transcription failed"))
        finally:
            with self._lock:
                self._busy = False
