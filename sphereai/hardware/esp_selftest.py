import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import soundfile as sf

from agents.voice_agent import VoiceAgent
from core.esp_audio import EspAudio


def _db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-9))


def main() -> None:
    esp = EspAudio()
    print(f"[ok] {esp.port} answered PING")

    t = np.arange(0, 1.0, 1 / 16000)
    tone = (0.3 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)
    print("[1/4] playing a 440 Hz beep. You should hear it from the speaker.")
    esp.play(tone, 16000)

    input("[2/4] press Enter, then talk normally for 4 seconds... ")
    print("recording...")
    y = esp.record(4.0)
    rms = float(np.sqrt(np.mean(y ** 2)))
    peak = float(np.max(np.abs(y)))
    print(f"rms={rms:.4f} ({_db(rms):.1f} dBFS)  peak={peak:.3f} ({_db(peak):.1f} dBFS)")
    if peak >= 0.99:
        print("clipping: set ESP_MIC_GAIN below 1.0 or raise MIC_SHIFT in firmware config.h")
    elif rms < 0.01:
        print("very quiet: set ESP_MIC_GAIN=4 (or 8) and rerun")
    sf.write("/tmp/esp_selftest.wav", y, 16000)

    print("[3/4] playing your recording back")
    esp.play(y, 16000)

    print("[4/4] voice features:", VoiceAgent().analyze_signal(y))
    esp.close()


if __name__ == "__main__":
    main()
