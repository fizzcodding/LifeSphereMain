from dataclasses import dataclass
from typing import Optional


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
    """
    Extracts acoustic features from audio input.
    Currently returns mock data. Real implementation requires
    a microphone input and librosa/pyAudioAnalysis feature extraction.
    Hardware integration: Phase 2.
    """

    def analyze(self, audio_path: Optional[str] = None) -> VoiceResult:
        if audio_path is None:
            return mock_voice()

        raise NotImplementedError(
            "Real audio analysis not yet implemented. "
            "Requires librosa and a microphone or audio file input."
        )
