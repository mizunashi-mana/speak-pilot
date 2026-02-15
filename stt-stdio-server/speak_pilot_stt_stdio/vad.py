"""Silero VAD wrapper with speech buffering."""

from __future__ import annotations

import logging
from enum import Enum

import numpy as np
import torch
from silero_vad import VADIterator, load_silero_vad

from .audio import SAMPLE_RATE

logger = logging.getLogger(__name__)


class VadEvent(Enum):
    SPEECH_START = "speech_start"
    SPEECH_END = "speech_end"


class VadProcessor:
    """Processes audio frames through Silero VAD and buffers speech segments."""

    def __init__(
        self,
        threshold: float = 0.5,
        min_silence_ms: int = 500,
        speech_pad_ms: int = 100,
    ):
        self._model = load_silero_vad()
        self._iterator = VADIterator(
            self._model,
            threshold=threshold,
            sampling_rate=SAMPLE_RATE,
            min_silence_duration_ms=min_silence_ms,
            speech_pad_ms=speech_pad_ms,
        )
        self._speech_buffer: list[np.ndarray] = []
        logger.info(
            "VAD initialized (threshold=%.2f, min_silence=%dms, speech_pad=%dms)",
            threshold,
            min_silence_ms,
            speech_pad_ms,
        )

    def process_frame(
        self, frame: np.ndarray
    ) -> tuple[VadEvent | None, np.ndarray | None]:
        """Process a single audio frame.

        Returns:
            (event, utterance_audio):
            - (SPEECH_START, None) when speech begins
            - (SPEECH_END, concatenated_audio) when speech ends
            - (None, None) otherwise
        """
        frame_tensor = torch.from_numpy(frame)
        speech_dict = self._iterator(frame_tensor)

        event = None
        utterance = None

        if speech_dict is not None:
            if "start" in speech_dict:
                self._speech_buffer.clear()
                event = VadEvent.SPEECH_START
            if "end" in speech_dict:
                if self._speech_buffer:
                    utterance = np.concatenate(self._speech_buffer)
                self._speech_buffer.clear()
                event = VadEvent.SPEECH_END

        # Buffer frames while speech is active
        if self._iterator.triggered:
            self._speech_buffer.append(frame.copy())

        return event, utterance

    def reset(self) -> None:
        """Reset VAD state (call on stop)."""
        self._iterator.reset_states()
        self._speech_buffer.clear()
