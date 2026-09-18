from dataclasses import dataclass
from fusion.emotional_fusion import FusedState


@dataclass
class EmotionalState:
    label: str            # e.g. "calm", "mild_distress", "acute_distress", "elevated_anxiety"
    arousal: float        # 0.0–1.0
    valence: float        # -1.0 to 1.0
    convergence: int      # 0–3 modalities agreeing on distress
    confidence: float     # how confident we are in this label
    needs_support: bool   # whether ResponseAgent should prioritize emotional support
    alert_level: str      # "none", "low", "medium", "high"


def _classify_label(arousal: float, valence: float, convergence: int) -> str:
    if valence >= -0.1 and arousal < 0.3:
        return "calm"
    if valence >= -0.1 and arousal >= 0.3:
        return "engaged"
    if valence < -0.1 and arousal < 0.25:
        return "low_mood"
    if valence < -0.1 and arousal < 0.5 and convergence <= 1:
        return "mild_distress"
    if valence < -0.3 and arousal >= 0.5 and convergence >= 2:
        return "acute_distress"
    if arousal >= 0.5 and convergence >= 2:
        return "elevated_anxiety"
    return "mild_distress"


def _alert_level(label: str, convergence: int) -> str:
    if label == "acute_distress" or convergence == 3:
        return "high"
    if label in ("elevated_anxiety", "mild_distress") and convergence >= 2:
        return "medium"
    if label in ("mild_distress", "low_mood") and convergence >= 1:
        return "low"
    return "none"


class EmotionalAgent:
    """
    Interprets a FusedState into a final EmotionalState.
    This is the only layer allowed to make psychological interpretations.
    All labels are expressed with appropriate uncertainty —
    this is not a medical diagnosis.
    """

    def interpret(self, fused: FusedState) -> EmotionalState:
        label = _classify_label(fused.arousal, fused.valence, fused.convergence)
        alert = _alert_level(label, fused.convergence)

        # Confidence is higher when multiple modalities agree
        confidence = 0.5 + (fused.convergence * 0.15)
        confidence = round(min(confidence, 0.95), 2)

        needs_support = label in (
            "mild_distress", "acute_distress", "elevated_anxiety", "low_mood"
        )

        return EmotionalState(
            label=label,
            arousal=fused.arousal,
            valence=fused.valence,
            convergence=fused.convergence,
            confidence=confidence,
            needs_support=needs_support,
            alert_level=alert,
        )
