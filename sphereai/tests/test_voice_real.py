import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import io
import wave

import numpy as np
import pytest

from agents.voice_agent import VoiceAgent, VoiceResult, SAMPLE_RATE


def _sine(freq: float = 440.0, duration: float = 1.0, sr: int = SAMPLE_RATE) -> np.ndarray:
    t = np.arange(int(sr * duration)) / sr
    return (0.3 * np.sin(2 * np.pi * freq * t)).astype(np.float32)


def _silence(duration: float = 1.0, sr: int = SAMPLE_RATE) -> np.ndarray:
    return np.zeros(int(sr * duration), dtype=np.float32)


def test_to_wav_bytes_produces_valid_wav():
    agent = VoiceAgent()
    y = _sine()
    data = agent.to_wav_bytes(y)
    buf = io.BytesIO(data)
    with wave.open(buf, "rb") as wf:
        assert wf.getnchannels() == 1
        assert wf.getsampwidth() == 2
        assert wf.getframerate() == SAMPLE_RATE
        assert wf.getnframes() == len(y)


def test_to_wav_bytes_clips_correctly():
    agent = VoiceAgent()
    y = np.array([2.0, -2.0, 0.5], dtype=np.float32)
    data = agent.to_wav_bytes(y)
    buf = io.BytesIO(data)
    with wave.open(buf, "rb") as wf:
        raw = wf.readframes(3)
    samples = np.frombuffer(raw, dtype="<i2")
    assert samples[0] == 32767
    assert samples[1] == -32767 or samples[1] == -32768
    assert -32768 <= samples[2] <= 32767


def test_analyze_signal_returns_voice_result():
    agent = VoiceAgent()
    y = _sine(440.0, 2.0)
    result = agent.analyze_signal(y)
    assert isinstance(result, VoiceResult)
    assert result.source == "live"


def test_analyze_signal_energy_nonzero_for_tone():
    agent = VoiceAgent()
    y = _sine(440.0, 1.0)
    result = agent.analyze_signal(y)
    assert result.energy > 0.0


def test_analyze_signal_energy_near_zero_for_silence():
    agent = VoiceAgent()
    y = _silence(1.0)
    result = agent.analyze_signal(y)
    assert result.energy < 0.01


def test_analyze_signal_empty_returns_mock():
    agent = VoiceAgent()
    result = agent.analyze_signal(np.array([], dtype=np.float32))
    assert result.source == "mock"


def test_analyze_signal_none_returns_mock():
    agent = VoiceAgent()
    result = agent.analyze_signal(None)
    assert result.source == "mock"


def test_analyze_signal_bounds():
    agent = VoiceAgent()
    y = _sine(300.0, 3.0)
    result = agent.analyze_signal(y)
    assert result.energy >= 0.0
    assert result.pitch_mean >= 0.0
    assert result.speaking_rate >= 0.0
    assert isinstance(result.tremor, bool)
    assert isinstance(result.long_pauses, bool)


def test_warmup_runs_without_error():
    agent = VoiceAgent()
    agent.warmup()


def test_mock_voice_backward_compat():
    agent = VoiceAgent()
    result = agent.analyze(audio_path=None)
    assert result.source == "mock"
