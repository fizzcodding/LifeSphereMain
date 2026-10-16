import time
import os
import requests
from dotenv import load_dotenv
from agents.biology_agent import VitalSigns

_ENV_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(_ENV_PATH)

_DATABASE_URL = 'https://hollow-core-default-rtdb.firebaseio.com'
_AUTH_URL = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
_TIMEOUT = 5
_STALE_THRESHOLD_S = 30


class SphereCoreClient:
    def __init__(self):
        self._token: str | None = None
        self._uid: str | None = None
        self._token_expires_at: float = 0.0

    def authenticate(self, email: str | None = None, password: str | None = None) -> bool:
        email = email or os.getenv('FIREBASE_EMAIL')
        password = password or os.getenv('FIREBASE_PASSWORD')
        api_key = os.getenv('FIREBASE_WEB_API_KEY')
        if not email or not password:
            raise ValueError('Email and password required')
        if not api_key:
            raise ValueError('FIREBASE_WEB_API_KEY not set in .env')

        res = requests.post(
            f'{_AUTH_URL}?key={api_key}',
            json={
                'email': email,
                'password': password,
                'returnSecureToken': True,
            },
            timeout=_TIMEOUT,
        )

        if res.status_code != 200:
            raise RuntimeError(
                f'Firebase auth failed: {res.json().get("error", {}).get("message")}'
            )

        data = res.json()
        self._token = data['idToken']
        self._uid = data['localId']
        self._token_expires_at = time.time() + 3540
        return True

    def _refresh_if_needed(self) -> None:
        if self._token and time.time() >= self._token_expires_at:
            self.authenticate()

    def _ensure_auth(self) -> None:
        self._refresh_if_needed()
        if not self._token:
            self.authenticate()

    def _db_url(self, path: str) -> str:
        return f'{_DATABASE_URL}/users/{self._uid}/{path}.json?auth={self._token}'

    def get_vitals(self) -> VitalSigns | None:
        self._ensure_auth()

        def _fetch() -> requests.Response:
            return requests.get(self._db_url('vital32'), timeout=_TIMEOUT)

        res = _fetch()
        if res.status_code == 401:
            self.authenticate()
            try:
                res = _fetch()
            except Exception:
                return None

        if res.status_code != 200:
            return None

        data = res.json()

        hr = data.get('hr', {}).get('currently') if data else None
        spo2 = data.get('spo2', {}).get('currently') if data else None
        temp = data.get('temp', {}).get('currently') if data else None
        steps = data.get('steps', {}).get('currently') if data else None
        server_ts = data.get('status', {}).get('server_ts') if data else None

        if isinstance(server_ts, (int, float)):
            age_ms = time.time() * 1000 - server_ts
            if age_ms > _STALE_THRESHOLD_S * 1000:
                return None

        try:
            hr = float(hr) if hr is not None else None
        except (TypeError, ValueError):
            hr = None

        try:
            spo2 = float(spo2) if spo2 is not None else None
        except (TypeError, ValueError):
            spo2 = None

        try:
            temp = float(temp) if temp is not None else None
        except (TypeError, ValueError):
            temp = None

        activity = min(float(steps) / 10000.0, 1.0) if steps is not None else 0.0

        return VitalSigns(
            heart_rate=hr,
            spo2=spo2,
            skin_temperature=temp,
            activity=activity,
        )

    def get_reminders(self) -> list[dict]:
        self._ensure_auth()
        res = requests.get(self._db_url('reminders'), timeout=_TIMEOUT)
        if res.status_code != 200 or res.json() is None:
            return []
        data = res.json()
        reminders = []
        for key, val in data.items():
            if isinstance(val, dict):
                reminders.append({**val, '_id': key})
        return reminders

    def add_reminder(
        self,
        name: str,
        slot: str,
        time: str,
        days: list[str],
        note: str | None = None,
    ) -> bool:
        self._ensure_auth()

        reminder = {
            'name': name,
            'slot': slot,
            'time': time,
            'days': days,
        }
        if note:
            reminder['note'] = note

        res = requests.post(
            self._db_url('reminders'),
            json=reminder,
            timeout=_TIMEOUT,
        )
        return res.status_code == 200

    def write_alert(self, level: str, label: str, message: str) -> bool:
        self._ensure_auth()
        payload = {
            'level': level,
            'label': label,
            'message': message,
            'ts': int(time.time() * 1000),
        }
        res = requests.post(self._db_url('alerts'), json=payload, timeout=_TIMEOUT)
        return res.status_code == 200

    def write_ai_suggestions(self, suggestions: list[str]) -> bool:
        self._ensure_auth()
        payload = {str(i): s for i, s in enumerate(suggestions[:3])}
        res = requests.put(
            self._db_url('vital32/aiSuggestions'),
            json=payload,
            timeout=_TIMEOUT,
        )
        return res.status_code == 200
