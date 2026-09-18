from dataclasses import dataclass
from typing import Optional
from agents.language_agent import LanguageResult
from agents.biology_agent import BiologyResult
from agents.voice_agent import VoiceResult


@dataclass
class FusedState:
    # Physiological arousal signal 0.0–1.0
    # High = body is activated (elevated HR, low SpO2, tremor, high energy)
    arousal: float

    # Emotional valence signal -1.0 to 1.0
    # Negative = distress/negative affect, Positive = calm/positive affect
    valence: float

    # How many independent modalities agree something is wrong
    # 0 = all clear, 3 = all three modalities flagging distress
    convergence: int

    # Dominant emotion label from language (most reliable single label)
    dominant_emotion: Optional[str]

    # Rich narrative context from language agent
    emotional_context: str

    # Whether biology is from real hardware or mock
    biology_source: str

    # Whether voice is from real hardware or mock
    voice_source: str


_NEGATIVE_EMOTIONS = {
    "sadness", "grief", "anger", "fear", "anxiety", "stress",
    "loneliness", "despair", "frustration", "worry", "panic",
    "distress", "depression", "hopelessness", "shame", "guilt",
}

_POSITIVE_EMOTIONS = {
    "joy", "happiness", "contentment", "calm", "relief",
    "gratitude", "hope", "excitement", "love", "pride",
}


def _language_valence(lang: LanguageResult) -> float:
    emotion = (lang.emotion or "").lower()
    if emotion in _NEGATIVE_EMOTIONS:
        return -0.6 * lang.confidence
    if emotion in _POSITIVE_EMOTIONS:
        return 0.6 * lang.confidence
    return 0.0


def _biology_arousal(bio: BiologyResult) -> float:
    score = 0.0
    if bio.heart_rate_elevated:
        score += 0.4
    if bio.spo2_low:
        score += 0.35
    if bio.temperature_abnormal:
        score += 0.15
    # High activity raises arousal but is not inherently distress
    if bio.activity_level == "active":
        score += 0.1
    return min(score, 1.0)


def _voice_arousal(voice: VoiceResult) -> float:
    score = 0.0
    if voice.tremor:
        score += 0.4
    if voice.long_pauses:
        score += 0.2
    if voice.energy > 0.75:
        score += 0.2
    if voice.energy < 0.15:
        score += 0.15
    if voice.speaking_rate > 5.5:
        score += 0.15
    if voice.speaking_rate < 1.5:
        score += 0.15
    return min(score, 1.0)


def _voice_valence(voice: VoiceResult) -> float:
    if voice.tremor or voice.long_pauses:
        return -0.3
    if voice.energy < 0.15:
        return -0.2
    return 0.0


class EmotionalFusion:
    """
    Combines LanguageResult, BiologyResult, and VoiceResult into
    a single FusedState. Does not make emotional decisions —
    that is EmotionalAgent's job. This layer only combines signals.

    Weights reflect confidence hierarchy:
    - Language carries most weight (LLM semantic understanding)
    - Biology is objective but indirect
    - Voice adds prosodic signal (currently mock)
    """

    LANGUAGE_WEIGHT = 0.55
    BIOLOGY_WEIGHT = 0.30
    VOICE_WEIGHT = 0.15

    def fuse(
        self,
        lang: LanguageResult,
        bio: BiologyResult,
        voice: VoiceResult,
    ) -> FusedState:
        lang_valence = _language_valence(lang)
        bio_arousal = _biology_arousal(bio)
        voice_arousal = _voice_arousal(voice)
        voice_valence = _voice_valence(voice)

        arousal = (
            bio_arousal * self.BIOLOGY_WEIGHT +
            voice_arousal * self.VOICE_WEIGHT +
            abs(lang_valence) * self.LANGUAGE_WEIGHT
        )

        valence = (
            lang_valence * self.LANGUAGE_WEIGHT +
            voice_valence * (self.VOICE_WEIGHT + self.BIOLOGY_WEIGHT)
        )

        # Convergence: count how many modalities independently signal distress
        convergence = 0
        if lang_valence < -0.3:
            convergence += 1
        if bio_arousal > 0.35:
            convergence += 1
        if voice_arousal > 0.3 or voice_valence < -0.2:
            convergence += 1

        return FusedState(
            arousal=round(min(max(arousal, 0.0), 1.0), 3),
            valence=round(min(max(valence, -1.0), 1.0), 3),
            convergence=convergence,
            dominant_emotion=lang.emotion,
            emotional_context=lang.emotional_context,
            biology_source=bio.source,
            voice_source=voice.source,
        )
