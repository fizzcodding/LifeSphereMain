from dataclasses import dataclass
from typing import Optional
import json
from core.gemini import generate


@dataclass
class LanguageResult:
    intent: str
    emotion: Optional[str]
    emotional_context: str
    confidence: float
    entities: dict
    raw_text: str


class LanguageAgent:
    def analyze(self, text: str) -> LanguageResult:
        prompt = f"""Analyze this message from an elderly care app user. Return JSON only.

Fields:
- intent: one of emotional_support, get_vitals, medication_reminder, list_reminders, navigate, greeting, general_query, unknown
- emotion: most prominent emotional state, or null
- emotional_context: detailed description of the user's emotional/psychological state
- confidence: float 0.0–1.0
- entities: named entities (people, places, times, medical terms)

{{"intent": "...", "emotion": "...", "emotional_context": "...", "confidence": 0.0, "entities": {{}}}}

Message: {text}"""

        data = generate(prompt)
        if isinstance(data, str):
            data = json.loads(data)

        return LanguageResult(
            intent=data["intent"],
            emotion=data.get("emotion"),
            emotional_context=data["emotional_context"],
            confidence=float(data["confidence"]),
            entities=data.get("entities", {}),
            raw_text=text,
        )
