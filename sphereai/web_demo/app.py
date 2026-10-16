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
from core.crisis import is_crisis, crisis_response
from core.reminder_utils import infer_slot, validate_reminder

app = Flask(__name__)
app.secret_key = os.urandom(24)
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'

lang_agent = LanguageAgent()
bio_agent = BiologyAgent()
voice_agent = VoiceAgent()
emotional_agent = EmotionalAgent()
fusion = EmotionalFusion()
response_agent = ResponseAgent()
voice_agent.warmup()
_last_voice: dict = {}

_clients: dict[str, SphereCoreClient] = {}
_client_emails: dict[str, str | None] = {}


def _get_client(session_id: str) -> SphereCoreClient:
    if session_id not in _clients:
        _clients[session_id] = SphereCoreClient()
        _client_emails[session_id] = None
    return _clients[session_id]


def invalidate_client(session_id: str) -> None:
    _clients.pop(session_id, None)
    _client_emails.pop(session_id, None)


@app.route('/')
def index():
    with open(os.path.join(os.path.dirname(__file__), 'index.html')) as f:
        return f.read()


@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email', '').strip()
    password = data.get('password', '')
    if not email or not password:
        return jsonify({'ok': False, 'error': 'Email and password required'}), 400

    sid = session.get('id') or os.urandom(16).hex()
    session['id'] = sid
    if _client_emails.get(sid) not in (None, email):
        invalidate_client(sid)
    client = _get_client(sid)
    try:
        client.authenticate(email, password)
        _client_emails[sid] = email
        return jsonify({'ok': True})
    except Exception:
        return jsonify({'ok': False, 'error': 'Authentication failed'}), 401


@app.route('/api/skip_login', methods=['POST'])
def skip_login():
    sid = os.urandom(16).hex()
    session['id'] = sid
    _clients[sid] = SphereCoreClient()
    _client_emails[sid] = None
    return jsonify({'ok': True, 'mode': 'mock'})


@app.route('/api/voice', methods=['POST'])
def voice():
    sid = session.get('id')
    if sid is None:
        return jsonify({'error': 'No session'}), 400
    try:
        y = voice_agent.listen(6.0)
        text = transcribe(voice_agent.to_wav_bytes(y)).strip()
        result = voice_agent.analyze_signal(y)
    except Exception:
        return jsonify({'error': 'Service unavailable'}), 503
    if not text:
        return jsonify({'error': 'Nothing heard'}), 400
    _last_voice[sid] = result
    return jsonify({'text': text, 'source': result.source})


@app.route('/api/chat', methods=['POST'])
def chat():
    sid = session.get('id')
    if sid is None:
        return jsonify({'error': 'No session'}), 400

    data = request.json
    msg = (data.get('message') or '').strip()
    if not msg:
        return jsonify({'error': 'Empty message'}), 400
    msg = msg[:500]

    client = _get_client(sid)
    firebase_ready = client._uid is not None

    try:
        live = client.get_vitals() if firebase_ready else None
        vitals = live if live is not None else mock_vitals()
        bio_source = 'vital32_live' if live is not None else 'mock'
        voice_result = _last_voice.pop(sid, None) or mock_voice()
        lang_result = lang_agent.analyze(msg)
        bio_result = bio_agent.analyze(vitals, source=bio_source)
        fused = fusion.fuse(lang_result, bio_result, voice_result)
        emotional_state = emotional_agent.interpret(fused)
        response_result = response_agent.generate(lang_result, emotional_state)
    except Exception:
        return jsonify({'error': 'Service unavailable'}), 503

    emergency_num = os.getenv('CRISIS_EMERGENCY_NUMBER', '999')
    if is_crisis(msg, lang_result.emotion):
        crisis_reply = crisis_response(emergency_num)
        speak(crisis_reply)
        if firebase_ready:
            try:
                client.write_alert('high', 'crisis', 'Self-harm or suicidal language detected')
            except Exception:
                pass
        return jsonify({
            'reply': crisis_reply,
            'intent': 'emotional_support',
            'emotion': lang_result.emotion,
            'confidence': round(lang_result.confidence, 2),
            'emotional_context': lang_result.emotional_context,
            'emotional_state': {
                'label': 'acute_distress',
                'arousal': 1.0,
                'valence': -1.0,
                'convergence': 3,
                'confidence': 0.95,
                'needs_support': True,
                'alert_level': 'high',
            },
            'biology': {
                'heart_rate': bio_result.vitals.heart_rate,
                'spo2': bio_result.vitals.spo2 if bio_result.vitals.spo2 is not None else None,
                'temperature': bio_result.vitals.skin_temperature,
                'activity_level': bio_result.activity_level,
                'stress_indicators': bio_result.stress_indicators,
                'heart_rate_elevated': bio_result.heart_rate_elevated,
                'spo2_low': bio_result.spo2_low,
                'source': bio_result.source,
            },
            'action': None,
            'action_status': None,
            'crisis': True,
        })

    speak(response_result.reply)

    action_status = None
    if response_result.action and firebase_ready:
        intent = response_result.action.get('intent')
        if intent == 'medication_reminder':
            entities = lang_result.entities
            name = entities.get('medication') or entities.get('medicine') or 'Medication'
            time_str = entities.get('time', '08:00')
            slot = infer_slot(time_str)
            days = entities.get('days') or [
                'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
            ]
            note = entities.get('note')
            ok_val, err = validate_reminder(name, slot, time_str, days, note)
            if not ok_val:
                action_status = f'Reminder validation failed: {err}'
            else:
                ok = client.add_reminder(name=name, slot=slot, time=time_str, days=days, note=note)
                action_status = 'Reminder saved to Firebase.' if ok else 'Failed to save reminder.'

    return jsonify({
        'reply': response_result.reply,
        'intent': lang_result.intent,
        'emotion': lang_result.emotion,
        'confidence': round(lang_result.confidence, 2),
        'emotional_context': lang_result.emotional_context,
        'emotional_state': {
            'label': emotional_state.label,
            'arousal': emotional_state.arousal,
            'valence': emotional_state.valence,
            'convergence': emotional_state.convergence,
            'confidence': emotional_state.confidence,
            'needs_support': emotional_state.needs_support,
            'alert_level': emotional_state.alert_level,
        },
        'biology': {
            'heart_rate': bio_result.vitals.heart_rate if bio_result.vitals.heart_rate is not None else None,
            'spo2': bio_result.vitals.spo2 if bio_result.vitals.spo2 is not None else None,
            'temperature': bio_result.vitals.skin_temperature,
            'activity_level': bio_result.activity_level,
            'stress_indicators': bio_result.stress_indicators,
            'heart_rate_elevated': bio_result.heart_rate_elevated,
            'spo2_low': bio_result.spo2_low,
            'source': bio_result.source,
        },
        'action': response_result.action,
        'action_status': action_status,
    })


if __name__ == '__main__':
    app.run(debug=False, host='127.0.0.1', port=5050)
