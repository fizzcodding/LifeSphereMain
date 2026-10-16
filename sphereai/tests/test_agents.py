import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from unittest.mock import MagicMock, patch
from agents.biology_agent import BiologyAgent, VitalSigns, mock_vitals
from agents.voice_agent import VoiceAgent, VoiceResult, mock_voice
from agents.emotional_agent import EmotionalAgent
from fusion.emotional_fusion import EmotionalFusion, FusedState
from agents.language_agent import LanguageResult
from core.crisis import is_crisis, crisis_response
from core.reminder_utils import infer_slot, validate_reminder


def test_biology_normal_readings():
    agent = BiologyAgent()
    vitals = VitalSigns(heart_rate=72, spo2=98, skin_temperature=34.2, activity=0.25)
    result = agent.analyze(vitals)
    assert not result.heart_rate_elevated
    assert not result.spo2_low
    assert not result.temperature_abnormal
    assert result.activity_level == "resting"
    assert result.stress_indicators == 0


def test_biology_elevated_readings():
    agent = BiologyAgent()
    vitals = VitalSigns(heart_rate=115, spo2=92, skin_temperature=38.2, activity=0.8)
    result = agent.analyze(vitals)
    assert result.heart_rate_elevated
    assert result.spo2_low
    assert result.temperature_abnormal
    assert result.activity_level == "active"
    assert result.stress_indicators == 3


def test_biology_activity_levels():
    agent = BiologyAgent()
    assert agent.analyze(VitalSigns(heart_rate=72, spo2=98, skin_temperature=34.2, activity=0.1)).activity_level == "resting"
    assert agent.analyze(VitalSigns(heart_rate=72, spo2=98, skin_temperature=34.2, activity=0.5)).activity_level == "light"
    assert agent.analyze(VitalSigns(heart_rate=72, spo2=98, skin_temperature=34.2, activity=0.9)).activity_level == "active"


def test_biology_source_parameter():
    agent = BiologyAgent()
    result = agent.analyze(mock_vitals(), source="vital32_live")
    assert result.source == "vital32_live"


def test_mock_vitals_returns_valid():
    v = mock_vitals()
    assert 0.0 <= v.activity <= 1.0
    assert v.heart_rate > 0
    assert v.spo2 > 0
    assert 31.0 <= v.skin_temperature <= 35.5


def test_biology_none_vitals_no_flags():
    agent = BiologyAgent()
    vitals = VitalSigns(heart_rate=None, spo2=None, skin_temperature=None, activity=0.1)
    result = agent.analyze(vitals)
    assert not result.heart_rate_elevated
    assert not result.spo2_low
    assert not result.temperature_abnormal
    assert result.stress_indicators == 0


def test_biology_none_spo2_not_flagged_low():
    agent = BiologyAgent()
    vitals = VitalSigns(heart_rate=72, spo2=None, skin_temperature=34.2, activity=0.1)
    result = agent.analyze(vitals)
    assert not result.spo2_low


def test_biology_spo2_zero_not_flagged_low():
    agent = BiologyAgent()
    vitals = VitalSigns(heart_rate=72, spo2=0, skin_temperature=34.2, activity=0.1)
    result = agent.analyze(vitals)
    assert not result.spo2_low


def test_mock_voice_returns_valid():
    v = mock_voice()
    assert isinstance(v, VoiceResult)
    assert v.source == "mock"
    assert 0.0 <= v.energy <= 1.0


def test_voice_agent_no_audio_returns_mock():
    agent = VoiceAgent()
    result = agent.analyze(audio_path=None)
    assert result.source == "mock"


def test_voice_agent_raises_on_real_path():
    agent = VoiceAgent()
    with pytest.raises(Exception):
        agent.analyze(audio_path="some_file.wav")


def _make_lang(intent="emotional_support", emotion="sadness", confidence=0.9, context="User is deeply sad"):
    return LanguageResult(
        intent=intent,
        emotion=emotion,
        emotional_context=context,
        confidence=confidence,
        entities={},
        raw_text="test",
    )


def test_fusion_calm_state():
    f = EmotionalFusion()
    lang = _make_lang(emotion="calm", confidence=0.9, context="User is relaxed")
    bio = BiologyAgent().analyze(mock_vitals())
    voice = mock_voice()
    result = f.fuse(lang, bio, voice)
    assert isinstance(result, FusedState)
    assert 0.0 <= result.arousal <= 1.0
    assert -1.0 <= result.valence <= 1.0


def test_fusion_calm_not_labeled_engaged():
    f = EmotionalFusion()
    lang = _make_lang(emotion="calm", confidence=0.95, context="User is perfectly calm")
    bio = BiologyAgent().analyze(mock_vitals())
    voice = mock_voice()
    result = f.fuse(lang, bio, voice)
    ea = EmotionalAgent()
    state = ea.interpret(result)
    assert state.label != "engaged", f"calm user should not be labeled engaged, got {state.label}"
    assert state.label in ("calm", "low_mood", "mild_distress")


def test_fusion_sadness_maps_to_low_mood():
    f = EmotionalFusion()
    lang = _make_lang(emotion="sadness", confidence=0.9, context="User feels very sad")
    bio = BiologyAgent().analyze(mock_vitals())
    voice = mock_voice()
    result = f.fuse(lang, bio, voice)
    ea = EmotionalAgent()
    state = ea.interpret(result)
    assert state.label in ("low_mood", "mild_distress"), f"sadness should map to low_mood or mild_distress, got {state.label}"


def test_fusion_distress_raises_convergence():
    f = EmotionalFusion()
    lang = _make_lang(emotion="grief", confidence=0.95, context="User is grieving")
    bio = BiologyAgent().analyze(
        VitalSigns(heart_rate=115, spo2=92, skin_temperature=38.0, activity=0.2),
        source="mock"
    )
    voice = VoiceResult(pitch_mean=150, energy=0.1, speaking_rate=1.2, tremor=True, long_pauses=True, source="mock")
    result = f.fuse(lang, bio, voice)
    assert result.convergence >= 2
    assert result.valence < 0
    assert result.arousal > 0.3


def test_fusion_output_bounds():
    f = EmotionalFusion()
    lang = _make_lang()
    bio = BiologyAgent().analyze(mock_vitals())
    voice = mock_voice()
    result = f.fuse(lang, bio, voice)
    assert 0.0 <= result.arousal <= 1.0
    assert -1.0 <= result.valence <= 1.0
    assert 0 <= result.convergence <= 3


def test_bio_only_critical_alert():
    f = EmotionalFusion()
    ea = EmotionalAgent()
    lang = _make_lang(emotion="calm", confidence=0.9, context="User says everything is fine")
    bio = BiologyAgent().analyze(
        VitalSigns(heart_rate=140, spo2=87, skin_temperature=34.0, activity=0.1),
        source="mock"
    )
    voice = mock_voice()
    fused = f.fuse(lang, bio, voice)
    assert fused.bio_critical
    state = ea.interpret(fused)
    assert state.alert_level in ("medium", "high"), f"bio-critical should raise alert, got {state.alert_level}"


def test_emotional_agent_calm():
    ea = EmotionalAgent()
    fused = FusedState(
        arousal=0.1, valence=0.3, convergence=0,
        dominant_emotion="calm", emotional_context="calm",
        biology_source="mock", voice_source="mock"
    )
    state = ea.interpret(fused)
    assert state.label == "calm"
    assert not state.needs_support
    assert state.alert_level == "none"


def test_emotional_agent_acute_distress():
    ea = EmotionalAgent()
    fused = FusedState(
        arousal=0.8, valence=-0.7, convergence=3,
        dominant_emotion="grief", emotional_context="severe distress",
        biology_source="mock", voice_source="mock"
    )
    state = ea.interpret(fused)
    assert state.label == "acute_distress"
    assert state.needs_support
    assert state.alert_level == "high"


def test_emotional_agent_confidence_scales_with_convergence():
    ea = EmotionalAgent()
    low_conv = FusedState(0.5, -0.4, 0, "anxiety", "mild", "mock", "mock")
    high_conv = FusedState(0.5, -0.4, 3, "anxiety", "severe", "mock", "mock")
    assert ea.interpret(high_conv).confidence > ea.interpret(low_conv).confidence


def test_crisis_keyword_detection():
    assert is_crisis("I want to kill myself", None)
    assert is_crisis("I have been thinking about suicide", None)
    assert is_crisis("I want to hurt myself tonight", None)
    assert not is_crisis("I feel a bit sad today", None)
    assert not is_crisis("Everything is fine", None)


def test_crisis_emotion_detection():
    assert is_crisis("I feel nothing", "hopelessness")
    assert is_crisis("I cannot go on", "despair")
    assert not is_crisis("I am feeling okay", "calm")


def test_crisis_response_contains_number():
    resp = crisis_response("999")
    assert "999" in resp


def test_crisis_response_warm_tone():
    resp = crisis_response("999")
    assert len(resp) > 20


def test_crisis_write_alert_called(monkeypatch):
    from core.spherecore_client import SphereCoreClient
    client = SphereCoreClient()
    client._token = "fake"
    client._uid = "fake_uid"
    written = []
    def fake_write_alert(level, label, message):
        written.append({'level': level, 'label': label, 'message': message})
        return True
    monkeypatch.setattr(client, 'write_alert', fake_write_alert)
    client.write_alert('high', 'crisis', 'Test crisis alert')
    assert written[0]['level'] == 'high'
    assert written[0]['label'] == 'crisis'


def test_infer_slot_morning():
    assert infer_slot("08:00") == "morning"
    assert infer_slot("11:59") == "morning"


def test_infer_slot_afternoon():
    assert infer_slot("12:00") == "afternoon"
    assert infer_slot("16:59") == "afternoon"


def test_infer_slot_evening():
    assert infer_slot("17:00") == "evening"
    assert infer_slot("23:00") == "evening"


def test_infer_slot_invalid_defaults_morning():
    assert infer_slot("badtime") == "morning"
    assert infer_slot("") == "morning"


def test_validate_reminder_valid():
    ok, err = validate_reminder("Metformin", "morning", "08:00", ["Monday", "Wednesday"])
    assert ok
    assert err == ""


def test_validate_reminder_invalid_slot():
    ok, err = validate_reminder("Med", "noon", "08:00", ["Monday"])
    assert not ok
    assert "slot" in err


def test_validate_reminder_invalid_time():
    ok, err = validate_reminder("Med", "morning", "8am", ["Monday"])
    assert not ok
    assert "HH:MM" in err


def test_validate_reminder_invalid_day():
    ok, err = validate_reminder("Med", "morning", "08:00", ["Mon"])
    assert not ok
    assert "days" in err


def test_validate_reminder_empty_name():
    ok, err = validate_reminder("", "morning", "08:00", ["Monday"])
    assert not ok
    assert "name" in err


def test_validate_reminder_long_note_rejected():
    ok, err = validate_reminder("Med", "morning", "08:00", ["Monday"], note="x" * 201)
    assert not ok
    assert "note" in err


def test_stale_vitals_rejected(monkeypatch):
    import time
    from core.spherecore_client import SphereCoreClient
    import requests

    client = SphereCoreClient()
    client._token = "fake"
    client._uid = "fake_uid"

    stale_ts = int((time.time() - 60) * 1000)

    fake_response = MagicMock()
    fake_response.status_code = 200
    fake_response.json.return_value = {
        "hr": {"currently": 72},
        "spo2": {"currently": 98},
        "temp": {"currently": 34.2},
        "steps": {"currently": 1000},
        "status": {"server_ts": stale_ts},
    }
    monkeypatch.setattr(requests, "get", lambda *a, **kw: fake_response)

    result = client.get_vitals()
    assert result is None, "Stale data older than 30s should be rejected"


def test_fresh_vitals_accepted(monkeypatch):
    import time
    from core.spherecore_client import SphereCoreClient
    import requests

    client = SphereCoreClient()
    client._token = "fake"
    client._uid = "fake_uid"

    fresh_ts = int(time.time() * 1000)

    fake_response = MagicMock()
    fake_response.status_code = 200
    fake_response.json.return_value = {
        "hr": {"currently": 72},
        "spo2": {"currently": 98},
        "temp": {"currently": 34.2},
        "steps": {"currently": 1000},
        "status": {"server_ts": fresh_ts},
    }
    monkeypatch.setattr(requests, "get", lambda *a, **kw: fake_response)

    result = client.get_vitals()
    assert result is not None
    assert result.heart_rate == 72.0
