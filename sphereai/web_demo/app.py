import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, request, jsonify, session
from agents.language_agent import LanguageAgent
from agents.biology_agent import BiologyAgent, mock_vitals
from agents.voice_agent import VoiceAgent, mock_voice
from agents.response_agent import ResponseAgent
from agents.emotional_agent import EmotionalAgent
from fusion.emotional_fusion import EmotionalFusion
from core.spherecore_client import SphereCoreClient
from core.gemini import transcribe
from core.speech import speak

app = Flask(__name__)
app.secret_key = os.urandom(24)

lang_agent = LanguageAgent()
bio_agent = BiologyAgent()
voice_agent = VoiceAgent()
emotional_agent = EmotionalAgent()
fusion = EmotionalFusion()
response_agent = ResponseAgent()
voice_agent.warmup()
_last_voice: dict = {}

# Clients are cached per session for the lifetime of the process, including
# their _token/_uid. Tradeoff: SphereCoreClient reads credentials live from
# .env at authenticate() time, but a cached client keeps the token/uid from
# its last successful login — .env edits do NOT propagate into it, and
# Firebase idTokens expire (~1h) while _ensure_auth() only re-authenticates
# when _token is unset. Call invalidate_client() to force a fresh client.
_clients: dict[str, SphereCoreClient] = {}
_client_emails: dict[str, str | None] = {}  # email each client last authenticated with


def _get_client(session_id: str) -> SphereCoreClient:
    if session_id not in _clients:
        _clients[session_id] = SphereCoreClient()
        _client_emails[session_id] = None
    return _clients[session_id]


def invalidate_client(session_id: str) -> None:
    """Drop a cached client so the next request creates a fresh one."""
    _clients.pop(session_id, None)
    _client_emails.pop(session_id, None)


@app.route("/")
def index():
    with open(os.path.join(os.path.dirname(__file__), "index.html")) as f:
        return f.read()


_ENV_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")


def _save_credentials(email: str, password: str):
    try:
        with open(_ENV_PATH, "r") as f:
            lines = f.readlines()
        keys = {"FIREBASE_EMAIL": email, "FIREBASE_PASSWORD": password}
        updated = {k: False for k in keys}
        new_lines = []
        for line in lines:
            key = line.split("=")[0].strip()
            if key in keys:
                new_lines.append(f"{key}={keys[key]}\n")
                updated[key] = True
            else:
                new_lines.append(line)
        for key, value in keys.items():
            if not updated[key]:
                new_lines.append(f"{key}={value}\n")
        with open(_ENV_PATH, "w") as f:
            f.writelines(new_lines)
    except Exception:
        pass


@app.route("/api/login", methods=["POST"])
def login():
    data = request.json
    email = data.get("email", "").strip()
    password = data.get("password", "")
    if not email or not password:
        return jsonify({"ok": False, "error": "Email and password required"}), 400

    sid = session.get("id") or os.urandom(16).hex()
    session["id"] = sid
    # Re-authenticating overwrites _token/_uid, but if the account changed,
    # start from a clean client so no state from the old account lingers.
    if _client_emails.get(sid) not in (None, email):
        invalidate_client(sid)
    client = _get_client(sid)
    try:
        client.authenticate(email, password)
        _client_emails[sid] = email
        _save_credentials(email, password)
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 401


@app.route("/api/skip_login", methods=["POST"])
def skip_login():
    sid = os.urandom(16).hex()
    session["id"] = sid
    _clients[sid] = SphereCoreClient()
    _client_emails[sid] = None
    return jsonify({"ok": True, "mode": "mock"})


@app.route("/api/voice", methods=["POST"])
def voice():
    sid = session.get("id")
    try:
        y = voice_agent.listen(6.0)
        text = transcribe(voice_agent.to_wav_bytes(y)).strip()
        result = voice_agent.analyze_signal(y)
    except Exception as e:
        return jsonify({"error": f"Mic failed: {e}"}), 503
    if not text:
        return jsonify({"error": "Nothing heard"}), 400
    _last_voice[sid] = result
    return jsonify({"text": text, "source": result.source})


@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.json
    msg = (data.get("message") or "").strip()
    if not msg:
        return jsonify({"error": "Empty message"}), 400

    sid = session.get("id")
    client = _get_client(sid) if sid else SphereCoreClient()
    firebase_ready = client._uid is not None

    try:
        live = client.get_vitals() if firebase_ready else None
        vitals = live if live is not None else mock_vitals()
        bio_source = "vital32_live" if live is not None else "mock"
        voice_result = _last_voice.pop(sid, None) or mock_voice()
        lang_result = lang_agent.analyze(msg)
        bio_result = bio_agent.analyze(vitals, source=bio_source)
        fused = fusion.fuse(lang_result, bio_result, voice_result)
        emotional_state = emotional_agent.interpret(fused)
        response_result = response_agent.generate(lang_result, emotional_state)
    except Exception as e:
        return jsonify({"error": f"SphereAI unavailable: {e}"}), 503

    speak(response_result.reply)

    action_status = None
    if response_result.action and firebase_ready:
        intent = response_result.action.get("intent")
        if intent == "medication_reminder":
            entities = lang_result.entities
            name = entities.get("medication") or entities.get("medicine") or "Medication"
            time_str = entities.get("time", "08:00")
            slot = _infer_slot(time_str)
            days = entities.get("days") or ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            ok = client.add_reminder(name=name, slot=slot, time=time_str, days=days)
            action_status = "Reminder saved to Firebase." if ok else "Failed to save reminder."

    return jsonify({
        "reply": response_result.reply,
        "intent": lang_result.intent,
        "emotion": lang_result.emotion,
        "confidence": round(lang_result.confidence, 2),
        "emotional_context": lang_result.emotional_context,
        "emotional_state": {
            "label": emotional_state.label,
            "arousal": emotional_state.arousal,
            "valence": emotional_state.valence,
            "convergence": emotional_state.convergence,
            "confidence": emotional_state.confidence,
            "needs_support": emotional_state.needs_support,
            "alert_level": emotional_state.alert_level,
        },
        "biology": {
            "heart_rate": bio_result.vitals.heart_rate,
            "spo2": bio_result.vitals.spo2,
            "temperature": bio_result.vitals.skin_temperature,
            "activity_level": bio_result.activity_level,
            "stress_indicators": bio_result.stress_indicators,
            "heart_rate_elevated": bio_result.heart_rate_elevated,
            "spo2_low": bio_result.spo2_low,
            "source": bio_result.source,
        },
        "action": response_result.action,
        "action_status": action_status,
    })


def _infer_slot(time_str: str) -> str:
    try:
        hour = int(time_str.split(":")[0])
        if hour < 12:
            return "morning"
        elif hour < 17:
            return "afternoon"
        else:
            return "evening"
    except Exception:
        return "morning"


if __name__ == "__main__":
    app.run(debug=True, port=5050)
