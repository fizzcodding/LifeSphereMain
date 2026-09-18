from dataclasses import dataclass
from typing import Optional
import json
from core.gemini import generate
from agents.language_agent import LanguageResult
from agents.emotional_agent import EmotionalState

_ACTION_INTENTS = {"get_vitals", "navigate", "medication_reminder"}

_TONE_GUIDE = {
    "calm":             "The person is calm. Be warm and present. Match their energy.",
    "engaged":          "The person is engaged and active. Be responsive and clear.",
    "low_mood":         "The person seems subdued or low. Be gentle, slow, and non-intrusive. Don't force positivity.",
    "mild_distress":    "The person is experiencing some distress. Acknowledge it fully before anything else. Don't rush to fix. Just be with them.",
    "acute_distress":   "The person is in acute distress. This is your only priority. Drop everything else. Respond with deep warmth, presence, and zero clinical language. Do not offer solutions. Just hold space.",
    "elevated_anxiety": "The person is anxious. Speak slowly and calmly. Validate their feelings without amplifying them. Ground them gently.",
}


@dataclass
class ResponseResult:
    reply: str
    action: Optional[dict]


class ResponseAgent:
    def generate(self, lang_result: LanguageResult, emotional_state: EmotionalState) -> ResponseResult:
        needs_action = lang_result.intent in _ACTION_INTENTS
        tone_instruction = _TONE_GUIDE.get(emotional_state.label, _TONE_GUIDE["calm"])

        action_example = (
            f'{{"intent": "{lang_result.intent}"}}'
            if needs_action
            else "null"
        )

        action_instruction = (
            f'Set "action" to {{"intent": "{lang_result.intent}"}}. '
            f'Still lead with the emotional response first before any task acknowledgement.'
            if needs_action
            else 'Set "action" to null.'
        )

        prompt = f"""You are SphereAI — an emotionally intelligent AI companion built for elderly and vulnerable people.

You are not a chatbot. You are not an assistant. You are a presence.
You speak the way a deeply compassionate therapist would to someone they genuinely care about.
You never use clinical language, never list bullet points, never sound robotic.
You speak in flowing, natural sentences. You are unhurried.

CURRENT EMOTIONAL READING:
- Emotional state: {emotional_state.label}
- Arousal level: {emotional_state.arousal:.2f} (0=calm, 1=highly activated)
- Valence: {emotional_state.valence:.2f} (-1=very negative, +1=very positive)
- Modalities in agreement: {emotional_state.convergence}/3
- Detected emotion: {emotional_state.dominant_emotion or "none"}

WHAT THE PERSON SAID:
"{lang_result.raw_text}"

FULL EMOTIONAL CONTEXT:
{lang_result.emotional_context}

TONE GUIDANCE:
{tone_instruction}

REPLY RULES:
- 1 to 4 sentences maximum.
- If distress is present, address it first. Always.
- Never mention heart rate, SpO2, sensors, AI, or any system internals.
- Never say "I understand how you feel" — show it instead.
- Never use the word "certainly", "absolutely", "of course", or any filler affirmations.
- If the person seems to need silence more than words, say less.
- Sound like a human being who genuinely cares.

{action_instruction}

Return JSON only:
{{"reply": "<your reply>", "action": {action_example}}}"""

        data = generate(prompt)
        if isinstance(data, str):
            data = json.loads(data)

        return ResponseResult(
            reply=data["reply"],
            action=data.get("action"),
        )
