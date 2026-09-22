import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import pytest
from agents.voice_agent import VoiceAgent

SR = 16000


def _tone(seconds=3.0, tremor=False):
    t = np.arange(0, seconds, 1 / SR)
    if tremor:
        phase = 2 * np.pi * (150 * t - (12 / (2 * np.pi * 7)) * np.cos(2 * np.pi * 7 * t))
    else:
        phase = 2 * np.pi * 150 * t
    return (0.1 * np.sin(phase)).astype(np.float32)


def test_voice_signal_steady_tone():
    r = VoiceAgent().analyze_signal(_tone(), SR)
    assert r.source == "mic"
    assert 130 < r.pitch_mean < 170
    assert not r.tremor
    assert not r.long_pauses
    assert 0.0 <= r.energy <= 1.0


def test_voice_signal_tremor_detected():
    r = VoiceAgent().analyze_signal(_tone(tremor=True), SR)
    assert r.tremor


def test_voice_signal_long_pause_detected():
    burst = _tone(1.0)
    gap = np.zeros(int(SR * 1.5), dtype=np.float32)
    r = VoiceAgent().analyze_signal(np.concatenate([burst, gap, burst]), SR)
    assert r.long_pauses


def test_voice_signal_silence_falls_back_to_mock():
    r = VoiceAgent().analyze_signal(np.zeros(SR * 2, dtype=np.float32), SR)
    assert r.source == "mock"


def test_voice_agent_missing_file_raises():
    with pytest.raises(Exception):
        VoiceAgent().analyze(audio_path="does_not_exist.wav")


def test_wav_bytes_header():
    b = VoiceAgent().to_wav_bytes(_tone(0.5), SR)
    assert b[:4] == b"RIFF"
