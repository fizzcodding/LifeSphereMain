import requests
import os
from dotenv import load_dotenv
from agents.biology_agent import VitalSigns

# Explicit .env path (sphereai/.env) resolved from this file's location so that
# loading works regardless of the process's current working directory.
_ENV_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
load_dotenv(_ENV_PATH)

_DATABASE_URL = "https://hollow-core-default-rtdb.firebaseio.com"
_AUTH_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
_TIMEOUT = 5


class SphereCoreClient:
    def __init__(self):
        self._token: str | None = None
        self._uid: str | None = None

    def authenticate(self, email: str | None = None, password: str | None = None) -> bool:
        # Read credentials live so .env edits take effect without a process restart.
        email = email or os.getenv("FIREBASE_EMAIL")
        password = password or os.getenv("FIREBASE_PASSWORD")
        api_key = os.getenv("FIREBASE_WEB_API_KEY")
        if not email or not password:
            raise ValueError("Email and password required")
        if not api_key:
            raise ValueError("FIREBASE_WEB_API_KEY not set in .env")

        res = requests.post(
            f"{_AUTH_URL}?key={api_key}",
            json={
                "email": email,
                "password": password,
                "returnSecureToken": True,
            },
            timeout=_TIMEOUT,
        )

        if res.status_code != 200:
            raise RuntimeError(f"Firebase auth failed: {res.json().get('error', {}).get('message')}")

        data = res.json()
        self._token = data["idToken"]
        self._uid = data["localId"]
        return True

    def _ensure_auth(self):
        if not self._token:
            self.authenticate()

    def _db_url(self, path: str) -> str:
        return f"{_DATABASE_URL}/users/{self._uid}/{path}.json?auth={self._token}"

    def get_vitals(self) -> VitalSigns | None:
        self._ensure_auth()

        def _read(key: str) -> float | None:
            try:
                res = requests.get(self._db_url(f"vital32/{key}/currently"), timeout=_TIMEOUT)
                if res.status_code == 200 and res.json() is not None:
                    return float(res.json())
            except Exception:
                pass
            return None

        heart_rate = _read("hr")
        spo2 = _read("spo2")
        skin_temperature = _read("temp")
        steps = _read("steps")

        if not heart_rate or not spo2 or not skin_temperature:
            return None

        activity = min((steps or 0.0) / 10000.0, 1.0)

        return VitalSigns(
            heart_rate=heart_rate,
            spo2=spo2,
            skin_temperature=skin_temperature,
            activity=activity,
        )

    def get_reminders(self) -> list[dict]:
        self._ensure_auth()
        res = requests.get(self._db_url("reminders"), timeout=_TIMEOUT)
        if res.status_code != 200 or res.json() is None:
            return []
        data = res.json()
        reminders = []
        for key, val in data.items():
            if isinstance(val, dict):
                reminders.append({**val, "_id": key})
        return reminders

    def add_reminder(self, name: str, slot: str, time: str, days: list[str], note: str | None = None) -> bool:
        self._ensure_auth()

        reminder = {
            "name": name,
            "slot": slot,
            "time": time,
            "days": days,
        }
        if note:
            reminder["note"] = note

        res = requests.post(
            self._db_url("reminders"),
            json=reminder,
            timeout=_TIMEOUT,
        )
        return res.status_code == 200

    def write_ai_suggestions(self, suggestions: list[str]) -> bool:
        self._ensure_auth()

        payload = {str(i): s for i, s in enumerate(suggestions[:3])}
        res = requests.put(
            self._db_url("vital32/aiSuggestions"),
            json=payload,
            timeout=_TIMEOUT,
        )
        return res.status_code == 200
