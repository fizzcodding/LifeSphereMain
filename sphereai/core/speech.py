import os
import sys
import tempfile
import threading


def _speak_local(text: str) -> None:
    import pyttsx3

    engine = pyttsx3.init()
    engine.setProperty("rate", 150)
    engine.say(text)
    engine.runAndWait()


def _speak_esp(text: str) -> None:
    import pyttsx3
    import soundfile as sf
    from core.esp_audio import get_esp

    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        engine = pyttsx3.init()
        engine.setProperty("rate", 150)
        engine.save_to_file(text, path)
        engine.runAndWait()
        y, sr = sf.read(path, dtype="float32")
        get_esp().play(y, sr)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


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
