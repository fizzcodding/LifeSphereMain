from dataclasses import dataclass
from typing import Optional
import json
from core.gemini import generate

VALID_INTENTS = frozenset([
    'emotional_support',
    'get_vitals',
    'medication_reminder',
    'list_reminders',
    'navigate',
    'greeting',
    'general_query',
    'unknown',
])


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
        prompt = (
            'Analyze this message from an elderly care app user. Return JSON only.\n\n'
            'Fields:\n'
            '- intent: one of emotional_support, get_vitals, medication_reminder, '
            'list_reminders, navigate, greeting, general_query, unknown\n'
            '- emotion: most prominent emotional state, or null\n'
            '- emotional_context: detailed description of the emotional and psychological state\n'
            '- confidence: float 0.0 to 1.0\n'
            '- entities: named entities (people, places, times, medical terms)\n\n'
            '{"intent": "...", "emotion": "...", "emotional_context": "...", '
            '"confidence": 0.0, "entities": {}}\n\n'
            '<USER_INPUT>\n'
            f'{text}\n'
            '</USER_INPUT>'
        )

        raw = generate(prompt)

        if isinstance(raw, str):
            cleaned = raw.strip()
            if cleaned.startswith('```'):
                lines = cleaned.splitlines()
                if lines[0].startswith('```'):
                    lines = lines[1:]
                if lines and lines[-1].strip() == '```':
                    lines = lines[:-1]
                cleaned = '\n'.join(lines).strip()
            try:
                data = json.loads(cleaned)
            except (json.JSONDecodeError, ValueError):
                data = {}
        else:
            data = raw

        if isinstance(data, list):
            data = data[0] if data else {}

        if not isinstance(data, dict):
            data = {}

        intent = data.get('intent', 'unknown')
        if intent not in VALID_INTENTS:
            intent = 'unknown'

        confidence = 0.5
        try:
            confidence = float(data.get('confidence', 0.5))
        except (TypeError, ValueError):
            pass
        confidence = max(0.0, min(1.0, confidence))

        emotion = data.get('emotion') or None
        emotional_context = data.get('emotional_context', '') or ''
        raw_entities = data.get('entities')
        entities = raw_entities if isinstance(raw_entities, dict) else {}

        return LanguageResult(
            intent=intent,
            emotion=emotion,
            emotional_context=emotional_context,
            confidence=confidence,
            entities=entities,
            raw_text=text,
        )
