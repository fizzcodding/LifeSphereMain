from dataclasses import dataclass, field
from typing import Optional
from agents.language_agent import LanguageResult
from agents.biology_agent import BiologyResult
from agents.voice_agent import VoiceResult


@dataclass
class FusedState:
    arousal: float
    valence: float
    convergence: int
    dominant_emotion: Optional[str]
    emotional_context: str
    biology_source: str
    voice_source: str
    bio_critical: bool = False


_NEGATIVE_EMOTIONS = {
    "sadness", "grief", "anger", "fear", "anxiety", "stress",
    "loneliness", "despair", "frustration", "worry", "panic",
    "distress", "depression", "hopelessness", "shame", "guilt",
}

_POSITIVE_EMOTIONS = {
    "joy", "happiness", "contentment", "calm", "relief",
    "gratitude", "hope", "excitement", "love", "pride",
}

_LANGUAGE_AROUSAL_TABLE = {
    "anxiety": 0.7,
    "panic": 0.8,
    "anger": 0.75,
    "fear": 0.7,
    "excitement": 0.65,
    "sadness": 0.3,
    "grief": 0.3,
    "loneliness": 0.25,
    "depression": 0.2,
    "hopelessness": 0.2,
    "calm": 0.05,
    "contentment": 0.05,
    "relief": 0.1,
    "joy": 0.15,
    "gratitude": 0.1,
    "stress": 0.65,
    "frustration": 0.6,
    "worry": 0.55,
    "distress": 0.65,
    "despair": 0.35,
    "shame": 0.4,
    "guilt": 0.35,
    "happiness": 0.2,
    "hope": 0.15,
    "love": 0.1,
    "pride": 0.2,
}


def _language_valence(lang: LanguageResult) -> float:
    emotion = (lang.emotion or "").lower()
    if emotion in _NEGATIVE_EMOTIONS:
        return -0.6 * lang.confidence
    if emotion in _POSITIVE_EMOTIONS:
        return 0.6 * lang.confidence
    return 0.0


def _language_arousal(lang: LanguageResult) -> float:
    emotion_key = (lang.emotion or "").lower()
    lang_valence = _language_valence(lang)
    base = _LANGUAGE_AROUSAL_TABLE.get(emotion_key, abs(lang_valence))
    return base * lang.confidence


def _biology_arousal(bio: BiologyResult) -> float:
    score = 0.0
    if bio.heart_rate_elevated:
        score += 0.4
    if bio.spo2_low:
        score += 0.35
    if bio.temperature_abnormal:
        score += 0.15
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
        lang_arousal = _language_arousal(lang)
        bio_arousal = _biology_arousal(bio)
        voice_arousal = _voice_arousal(voice)
        voice_valence = _voice_valence(voice)

        arousal = (
            bio_arousal * self.BIOLOGY_WEIGHT
            + voice_arousal * self.VOICE_WEIGHT
            + lang_arousal * self.LANGUAGE_WEIGHT
        )

        valence = (
            lang_valence * self.LANGUAGE_WEIGHT
            + voice_valence * (self.VOICE_WEIGHT + self.BIOLOGY_WEIGHT)
        )

        convergence = 0
        if lang_valence < -0.3:
            convergence += 1
        if bio_arousal > 0.35:
            convergence += 1
        if voice_arousal > 0.3 or voice_valence < -0.2:
            convergence += 1

        hr_critical = (
            bio.heart_rate_elevated
            and bio.vitals.heart_rate is not None
            and bio.vitals.heart_rate > 130
        )
        spo2_critical = (
            bio.spo2_low
            and bio.vitals.spo2 is not None
            and bio.vitals.spo2 < 90
        )
        bio_critical = hr_critical or spo2_critical

        if bio_critical:
            arousal = max(arousal, 0.7)
            convergence = max(convergence, 2)

        return FusedState(
            arousal=round(min(max(arousal, 0.0), 1.0), 3),
            valence=round(min(max(valence, -1.0), 1.0), 3),
            convergence=convergence,
            dominant_emotion=lang.emotion,
            emotional_context=lang.emotional_context,
            biology_source=bio.source,
            voice_source=voice.source,
            bio_critical=bio_critical,
        )
