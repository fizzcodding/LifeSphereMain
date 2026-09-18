import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from agents.biology_agent import BiologyAgent, VitalSigns, mock_vitals
from agents.voice_agent import VoiceAgent, VoiceResult, mock_voice
from agents.emotional_agent import EmotionalAgent
from fusion.emotional_fusion import EmotionalFusion, FusedState
from agents.language_agent import LanguageResult


# ── BiologyAgent ──────────────────────────────────────────────────────────────

def test_biology_normal_readings():
    agent = BiologyAgent()
    vitals = VitalSigns(heart_rate=72, spo2=98, skin_temperature=36.6, activity=0.25)
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
    assert agent.analyze(VitalSigns(72, 98, 36.6, 0.1)).activity_level == "resting"
    assert agent.analyze(VitalSigns(72, 98, 36.6, 0.5)).activity_level == "light"
    assert agent.analyze(VitalSigns(72, 98, 36.6, 0.9)).activity_level == "active"


def test_biology_source_parameter():
    agent = BiologyAgent()
    result = agent.analyze(mock_vitals(), source="vital32_live")
    assert result.source == "vital32_live"


def test_mock_vitals_returns_valid():
    v = mock_vitals()
    assert 0.0 <= v.activity <= 1.0
    assert v.heart_rate > 0
    assert v.spo2 > 0


# ── VoiceAgent ────────────────────────────────────────────────────────────────

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
    with pytest.raises(NotImplementedError):
        agent.analyze(audio_path="some_file.wav")


# ── EmotionalFusion ───────────────────────────────────────────────────────────

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


# ── EmotionalAgent ────────────────────────────────────────────────────────────

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
