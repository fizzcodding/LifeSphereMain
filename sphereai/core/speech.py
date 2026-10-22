import os
import shutil
import subprocess
import sys
import tempfile
import threading

import numpy as np

_TTS_RATE = 24000


def _gemini_enabled() -> bool:
    return os.getenv("SPHEREAI_TTS", "local").strip().lower() == "gemini"


def _synth_gemini(text: str):
    from google.genai import types
    from core.gemini import _client, _call_with_timeout

    model = os.getenv("GEMINI_TTS_MODEL", "gemini-2.5-flash-preview-tts")
    voice = os.getenv("GEMINI_TTS_VOICE", "Sulafat")
    prompt = "Read this aloud in a clear, natural, steady voice at a normal speaking pace, like a kind caregiver talking to an elderly person. No whispering, no breathiness, no dramatic acting: " + text

    def _call():
        return _client.models.generate_content(
            model=model,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=voice)
                    )
                ),
            ),
        )

    resp = _call_with_timeout(_call, 20)
    data = resp.candidates[0].content.parts[0].inline_data.data
    y = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0
    if y.size == 0:
        raise RuntimeError("empty audio from Gemini TTS")
    return y, _TTS_RATE


def _synth_pyttsx3(text: str, path: str) -> None:
    import pyttsx3

    engine = pyttsx3.init()
    engine.setProperty("rate", 150)
    engine.save_to_file(text, path)
    engine.runAndWait()


def _synth_espeak(text: str, path: str) -> None:
    exe = shutil.which("espeak-ng") or shutil.which("espeak")
    if exe is None:
        raise RuntimeError("espeak-ng not installed")
    subprocess.run(
        [exe, "-s", "150", "-w", path, "--", text],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=30,
    )


def _load_wav(path: str):
    import soundfile as sf

    y, sr = sf.read(path, dtype="float32")
    if y.size == 0:
        raise RuntimeError("empty audio")
    return y, sr


def _synth_any(text: str):
    if _gemini_enabled():
        try:
            return _synth_gemini(text)
        except Exception as e:
            print(f"[tts] gemini failed, using fallback voice: {e}", file=sys.stderr)

    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        try:
            _synth_pyttsx3(text, path)
            return _load_wav(path)
        except Exception:
            _synth_espeak(text, path)
            return _load_wav(path)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def _speak_local(text: str) -> None:
    y, sr = _synth_any(text)
    import sounddevice as sd

    sd.play(y, sr)
    sd.wait()


def _speak_esp(text: str) -> None:
    from core.esp_audio import get_esp

    y, sr = _synth_any(text)
    get_esp().play(y, sr)


def speak_blocking(text: str) -> None:
    from core.esp_audio import use_esp

    if use_esp():
        _speak_esp(text)
    else:
        _speak_local(text)


def speak(text: str) -> None:
    def _run():
        try:
            speak_blocking(text)
        except Exception as e:
            print(f"[speech] {e}", file=sys.stderr)

    threading.Thread(target=_run, daemon=True).start()
