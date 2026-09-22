import io
import wave
from dataclasses import dataclass
from typing import Optional

import numpy as np

SAMPLE_RATE = 16000
HOP = 160


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


def _detect_tremor(f0: np.ndarray) -> bool:
    voiced = np.flatnonzero(~np.isnan(f0))
    if voiced.size < 50:
        return False
    runs = np.split(voiced, np.flatnonzero(np.diff(voiced) > 1) + 1)
    hop_s = HOP / SAMPLE_RATE
    for run in runs:
        if run.size < 50:
            continue
        seg = f0[run]
        cents = 1200.0 * np.log2(seg / np.median(seg))
        t = np.arange(cents.size)
        cents = cents - np.polyval(np.polyfit(t, cents, 2), t)
        spec = np.abs(np.fft.rfft(cents * np.hanning(cents.size))) ** 2
        freqs = np.fft.rfftfreq(cents.size, d=hop_s)
        band = spec[(freqs >= 4.0) & (freqs <= 12.0)].sum()
        total = spec[(freqs >= 0.5) & (freqs <= 20.0)].sum()
        if total > 0 and band / total > 0.5 and cents.std() > 8.0:
            return True
    return False


class VoiceAgent:
    def listen(self, seconds: float = 6.0, sr: int = SAMPLE_RATE) -> np.ndarray:
        from core.esp_audio import get_esp, use_esp

        if use_esp():
            return get_esp().record(seconds)

        import sounddevice as sd

        audio = sd.rec(int(seconds * sr), samplerate=sr, channels=1, dtype="float32")
        sd.wait()
        return audio[:, 0]

    def to_wav_bytes(self, y: np.ndarray, sr: int = SAMPLE_RATE) -> bytes:
        pcm = (np.clip(y, -1.0, 1.0) * 32767).astype(np.int16)
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(pcm.tobytes())
        return buf.getvalue()

    def warmup(self) -> None:
        t = np.arange(0, 1.0, 1 / SAMPLE_RATE)
        tone = (0.1 * np.sin(2 * np.pi * 150 * t)).astype(np.float32)
        self.analyze_signal(tone, SAMPLE_RATE)

    def analyze(self, audio_path: Optional[str] = None) -> VoiceResult:
        if audio_path is None:
            return mock_voice()
        import librosa

        y, sr = librosa.load(audio_path, sr=SAMPLE_RATE, mono=True)
        return self.analyze_signal(y, sr)

    def analyze_signal(self, y: np.ndarray, sr: int = SAMPLE_RATE) -> VoiceResult:
        import librosa

        y = np.asarray(y, dtype=np.float32)
        if y.size < sr // 2 or float(np.sqrt(np.mean(y ** 2))) < 0.003:
            return mock_voice()

        intervals = librosa.effects.split(y, top_db=30)
        if len(intervals) == 0:
            return mock_voice()

        speech = np.concatenate([y[s:e] for s, e in intervals])
        speech_dur = speech.size / sr
        if speech_dur < 0.4:
            return mock_voice()

        rms = float(np.sqrt(np.mean(speech ** 2)))
        energy = float(min(rms / 0.2, 1.0))

        f0, _, _ = librosa.pyin(
            y, fmin=70, fmax=400, sr=sr, frame_length=1024, hop_length=HOP
        )
        pitch_mean = float(np.nanmean(f0)) if np.any(~np.isnan(f0)) else 0.0
        tremor = _detect_tremor(f0)

        onsets = librosa.onset.onset_detect(y=speech, sr=sr, hop_length=HOP, units="time")
        speaking_rate = float(len(onsets) / speech_dur)

        gaps = [
            (intervals[i + 1][0] - intervals[i][1]) / sr
            for i in range(len(intervals) - 1)
        ]
        long_pauses = any(g > 1.0 for g in gaps)

        return VoiceResult(
            pitch_mean=round(pitch_mean, 1),
            energy=round(energy, 3),
            speaking_rate=round(speaking_rate, 2),
            tremor=bool(tremor),
            long_pauses=bool(long_pauses),
            source="mic",
        )
