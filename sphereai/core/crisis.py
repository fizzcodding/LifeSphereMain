from typing import Optional

CRISIS_KEYWORDS = frozenset([
    'suicide',
    'suicidal',
    'kill myself',
    'end my life',
    'want to die',
    'hurt myself',
    'self harm',
    'self-harm',
    'no reason to live',
    'cannot go on',
])

_CRISIS_EMOTIONS = frozenset(['suicidal', 'hopelessness', 'despair'])


def is_crisis(text: str, emotion: Optional[str]) -> bool:
    text_lower = text.lower()
    if any(kw in text_lower for kw in CRISIS_KEYWORDS):
        return True
    if emotion and emotion.lower() in _CRISIS_EMOTIONS:
        return True
    return False


def crisis_response(emergency_number: str = '999') -> str:
    return (
        f'What you are feeling right now matters deeply, and you do not have to carry it alone. '
        f'Please reach out to someone you trust, or call {emergency_number} right away so someone '
        f'can be there with you.'
    )
