"""Sounddevice audio capture with queue-based buffering."""

from __future__ import annotations

import logging
import queue

import numpy as np
import sounddevice as sd

logger = logging.getLogger(__name__)

SAMPLE_RATE = 16000
VAD_FRAME_MS = 32
VAD_FRAME_SAMPLES = int(SAMPLE_RATE * VAD_FRAME_MS / 1000)


class AudioCapture:
    """Captures audio from the default input device using sounddevice.

    Uses a queue.Queue for thread-safe frame delivery instead of busy-wait polling.
    """

    def __init__(
        self,
        sample_rate: int = SAMPLE_RATE,
        frame_samples: int = VAD_FRAME_SAMPLES,
    ):
        self._sample_rate = sample_rate
        self._frame_samples = frame_samples
        self._queue: queue.Queue[np.ndarray] = queue.Queue()
        self._stream: sd.InputStream | None = None

    def start(self) -> None:
        """Start audio capture."""
        self._stream = sd.InputStream(
            samplerate=self._sample_rate,
            channels=1,
            dtype=np.float32,
            blocksize=self._frame_samples,
            callback=self._callback,
        )
        self._stream.start()
        logger.info(
            "Audio capture started (rate=%d, frame=%d samples)",
            self._sample_rate,
            self._frame_samples,
        )

    def stop(self) -> None:
        """Stop audio capture and drain the queue."""
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None
            logger.info("Audio capture stopped")
        # Drain remaining frames
        while not self._queue.empty():
            try:
                self._queue.get_nowait()
            except queue.Empty:
                break

    def read_frame(self, timeout: float = 0.1) -> np.ndarray | None:
        """Read one VAD frame. Returns None on timeout."""
        try:
            return self._queue.get(timeout=timeout)
        except queue.Empty:
            return None

    def _callback(
        self,
        indata: np.ndarray,
        frames: int,
        time_info: object,
        status: sd.CallbackFlags,
    ) -> None:
        if status:
            logger.warning("Audio callback status: %s", status)
        self._queue.put(indata[:, 0].copy())
