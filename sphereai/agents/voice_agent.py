import io
import struct
import wave
from dataclasses import dataclass
from typing import Optional

import numpy as np

SAMPLE_RATE = 16000


@dataclass
class VoiceResult:
    pitch_mean: float
    energy: float
    speaking_rate: float
    tremor: bool
    long_pauses: bool
    source: str


def mock_voice() -> VoiceResult:
    return VoiceResult(
        pitch_mean=180.0,
        energy=0.45,
        speaking_rate=3.2,
        tremor=False,
        long_pauses=False,
        source="mock",
    )


class VoiceAgent:
    def warmup(self) -> None:
        import librosa
        _ = librosa.feature.rms(y=np.zeros(SAMPLE_RATE, dtype=np.float32))

    def listen(self, seconds: float = 6.0, sr: int = SAMPLE_RATE) -> np.ndarray:
        from core.esp_audio import get_esp, use_esp

        if use_esp():
            return get_esp().record(seconds)

        import sounddevice as sd

        audio = sd.rec(int(seconds * sr), samplerate=sr, channels=1, dtype="float32")
        sd.wait()
        return audio[:, 0]

    def to_wav_bytes(self, y: np.ndarray, sr: int = SAMPLE_RATE) -> bytes:
        pcm = (np.clip(y, -1.0, 1.0) * 32767).astype("<i2").tobytes()
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sr)
            wf.writeframes(pcm)
        return buf.getvalue()

    def analyze_signal(self, y: np.ndarray, sr: int = SAMPLE_RATE) -> VoiceResult:
        import librosa

        if y is None or len(y) == 0:
            return mock_voice()

        energy = float(np.sqrt(np.mean(y ** 2)))

        try:
            f0, voiced_flag, _ = librosa.pyin(
                y, fmin=librosa.note_to_hz("C2"), fmax=librosa.note_to_hz("C7"), sr=sr
            )
            voiced = f0[voiced_flag] if voiced_flag is not None else np.array([])
            pitch_mean = float(np.nanmean(voiced)) if len(voiced) > 0 else 0.0
        except Exception:
            pitch_mean = 0.0
            voiced = np.array([])

        hop = 512
        rms = librosa.feature.rms(y=y, hop_length=hop)[0]
        threshold = float(np.mean(rms)) * 0.3
        silent = rms < threshold
        transitions = int(np.sum(np.diff(silent.astype(int)) == 1))
        total_frames = len(rms)
        speaking_rate = transitions / (total_frames * hop / sr) if total_frames > 0 else 0.0

        pitch_vals = f0 if "f0" in dir() and f0 is not None else np.array([pitch_mean])
        valid = pitch_vals[~np.isnan(pitch_vals)] if len(pitch_vals) > 0 else np.array([])
        tremor = bool(np.std(valid) > 15.0) if len(valid) > 3 else False

        silent_runs = 0
        run = 0
        for s in silent:
            if s:
                run += 1
                if run == int(0.5 * sr / hop):
                    silent_runs += 1
            else:
                run = 0
        long_pauses = silent_runs >= 2

        return VoiceResult(
            pitch_mean=pitch_mean,
            energy=energy,
            speaking_rate=speaking_rate,
            tremor=tremor,
            long_pauses=long_pauses,
            source="live",
        )

    def analyze(self, audio_path: Optional[str] = None) -> VoiceResult:
        if audio_path is None:
            return mock_voice()
        raise NotImplementedError(
            "Real audio analysis not yet implemented. "
            "Requires librosa and a microphone or audio file input."
        )
