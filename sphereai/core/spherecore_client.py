import requests
import os
from dotenv import load_dotenv
from agents.biology_agent import VitalSigns

load_dotenv()

_FIREBASE_API_KEY = "AIzaSyAYjewzbRjz9szLLhdvh-ld3IN-jxAy0D0"
_DATABASE_URL = "https://hollow-core-default-rtdb.firebaseio.com"
_AUTH_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"

_FIREBASE_EMAIL = os.getenv("FIREBASE_EMAIL")
_FIREBASE_PASSWORD = os.getenv("FIREBASE_PASSWORD")


class SphereCoreClient:
    def __init__(self):
        self._token: str | None = None
        self._uid: str | None = None

    def authenticate(self, email: str | None = None, password: str | None = None) -> bool:
        email = email or _FIREBASE_EMAIL
        password = password or _FIREBASE_PASSWORD
        if not email or not password:
            raise ValueError("Email and password required")

        res = requests.post(
            f"{_AUTH_URL}?key={_FIREBASE_API_KEY}",
            json={
                "email": email,
                "password": password,
                "returnSecureToken": True,
            },
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

        def _read(key: str) -> float:
            res = requests.get(self._db_url(f"vital32/{key}/currently"))
            if res.status_code == 200 and res.json() is not None:
                return float(res.json())
            return 0.0

        heart_rate = _read("hr")
        spo2 = _read("spo2")
        skin_temperature = _read("temp")
        steps = _read("steps")

        # Normalize steps to 0.0–1.0 activity scale (cap at 10000 steps = 1.0)
        activity = min(steps / 10000.0, 1.0)

        return VitalSigns(
            heart_rate=heart_rate,
            spo2=spo2,
            skin_temperature=skin_temperature,
            activity=activity,
        )

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
        )
        return res.status_code == 200

    def write_ai_suggestions(self, suggestions: list[str]) -> bool:
        self._ensure_auth()

        payload = {str(i): s for i, s in enumerate(suggestions[:3])}
        res = requests.put(
            self._db_url("vital32/aiSuggestions"),
            json=payload,
        )
        return res.status_code == 200
