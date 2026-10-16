import re
from typing import Optional

VALID_SLOTS = frozenset(['morning', 'afternoon', 'evening'])

VALID_DAYS = frozenset([
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
])


def infer_slot(time_str: str) -> str:
    try:
        hour = int(time_str.split(':')[0])
        if hour < 12:
            return 'morning'
        elif hour < 17:
            return 'afternoon'
        else:
            return 'evening'
    except Exception:
        return 'morning'


def validate_reminder(
    name: Optional[str],
    slot: Optional[str],
    time_str: Optional[str],
    days: Optional[list],
    note: Optional[str] = None,
) -> tuple[bool, str]:
    if not name or not name.strip():
        return False, 'name is required'
    if len(name.strip()) > 80:
        return False, 'name too long'
    if slot not in VALID_SLOTS:
        return False, f'slot must be one of {VALID_SLOTS}'
    if not re.match(r'^([01]\d|2[0-3]):[0-5]\d$', time_str or ''):
        return False, 'time must be HH:MM 24h'
    if not days or not all(d in VALID_DAYS for d in days):
        return False, 'days must be valid weekday names'
    if note is not None and len(note) > 200:
        return False, 'note too long'
    return True, ''
