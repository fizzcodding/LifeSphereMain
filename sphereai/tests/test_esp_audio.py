import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pty
import select
import threading
import time
import tty

import numpy as np
import pytest

from core import esp_audio
from core.esp_audio import EspAudio, EspAudioError, CHUNK


class FakeEsp:
    def __init__(self, junk_on_boot=True, button_after=None, drop_acks=False):
        self.master, self.slave = pty.openpty()
        tty.setraw(self.master)
        self.name = os.ttyname(self.slave)
        self.received_play = bytearray()
        self.stop = threading.Event()
        self.junk_on_boot = junk_on_boot
        self.button_after = button_after
        self.drop_acks = drop_acks
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def _write(self, data: bytes):
        os.write(self.master, data)

    def _readline(self, buf: bytearray):
        while b"\n" not in buf:
            r, _, _ = select.select([self.master], [], [], 0.05)
            if self.stop.is_set():
                return None
            if r:
                buf += os.read(self.master, 4096)
        idx = buf.index(b"\n")
        line = bytes(buf[:idx]).strip()
        del buf[: idx + 1]
        return line

    def _run(self):
        if self.junk_on_boot:
            self._write(b"ets Jul 29 2019 12:21:46\nrst:0x1 (POWERON_RESET)\n")
        buf = bytearray()
        if self.button_after is not None:
            threading.Timer(
                self.button_after, lambda: self._write(b"EVT BTN\n")
            ).start()
        while not self.stop.is_set():
            line = self._readline(buf)
            if line is None:
                break
            if line == b"PING":
                self._write(b"PONG\n")
            elif line.startswith(b"REC "):
                ms = int(line.split()[1])
                n = ms * 32
                t = np.arange(n // 2) / 16000.0
                pcm = (0.3 * 32767 * np.sin(2 * np.pi * 440 * t) + 1500).astype("<i2")
                self._write(f"AUD {n}\n".encode())
                data = pcm.tobytes()
                for i in range(0, len(data), 2048):
                    self._write(data[i : i + 2048])
                self._write(b"OK\n")
            elif line.startswith(b"PLAY "):
                total = int(line.split()[1])
                self._write(b"RDY\n")
                remaining = total
                while remaining > 0 and not self.stop.is_set():
                    want = min(CHUNK, remaining)
                    while len(buf) < want and not self.stop.is_set():
                        r, _, _ = select.select([self.master], [], [], 0.05)
                        if r:
                            buf += os.read(self.master, 4096)
                    chunk = bytes(buf[:want])
                    del buf[:want]
                    self.received_play += chunk
                    time.sleep(0.002)
                    if not self.drop_acks:
                        self._write(b"K")
                    remaining -= want
                self._write(b"DONE\n")
            else:
                self._write(b"ERR unknown\n")

    def close(self):
        self.stop.set()
        self.thread.join(timeout=1)
        os.close(self.master)
        os.close(self.slave)


@pytest.fixture
def fake():
    f = FakeEsp()
    yield f
    f.close()


def test_sync_survives_boot_junk(fake):
    esp = EspAudio(port=fake.name)
    esp.close()


def test_record_length_and_dc_removed(fake):
    esp = EspAudio(port=fake.name)
    y = esp.record(1.0)
    esp.close()
    assert y.dtype == np.float32
    assert y.shape == (16000,)
    assert abs(float(np.mean(y))) < 0.01
    assert 0.2 < float(np.max(np.abs(y))) <= 1.0


def test_play_sends_every_byte_with_flow_control(fake):
    esp = EspAudio(port=fake.name)
    t = np.arange(0, 1.0, 1 / 22050)
    esp.play(0.5 * np.sin(2 * np.pi * 300 * t).astype(np.float32), 22050)
    esp.close()
    assert len(fake.received_play) == 32000


def test_play_stalls_without_acks():
    f = FakeEsp(drop_acks=True)
    try:
        esp = EspAudio(port=f.name)
        esp_audio.WINDOW = 4
        y = np.zeros(16000 * 2, dtype=np.float32)
        start = time.time()
        with pytest.raises(EspAudioError):
            esp.play(y, 16000)
        assert time.time() - start < 15
        esp.close()
    finally:
        f.close()


def test_wait_button_true_and_timeout():
    f = FakeEsp(button_after=0.6)
    try:
        esp = EspAudio(port=f.name)
        assert esp.wait_button(timeout=3.0) is True
        assert esp.wait_button(timeout=0.4) is False
        esp.close()
    finally:
        f.close()


def test_find_port_env_and_ambiguity(monkeypatch):
    class P:
        def __init__(self, dev, vid):
            self.device = dev
            self.vid = vid

    monkeypatch.delenv("ESP_AUDIO_PORT", raising=False)
    monkeypatch.setattr(
        esp_audio.list_ports, "comports", lambda: [P("/dev/ttyACM0", 0x303A), P("/dev/ttyUSB0", 0x10C4)]
    )
    with pytest.raises(EspAudioError):
        esp_audio.find_port()
    monkeypatch.setenv("ESP_AUDIO_PORT", "/dev/ttyACM0")
    assert esp_audio.find_port() == "/dev/ttyACM0"
    monkeypatch.delenv("ESP_AUDIO_PORT")
    monkeypatch.setattr(esp_audio.list_ports, "comports", lambda: [P("/dev/ttyACM0", 0x303A)])
    assert esp_audio.find_port() == "/dev/ttyACM0"


def test_use_esp_env(monkeypatch):
    monkeypatch.delenv("SPHEREAI_AUDIO", raising=False)
    assert esp_audio.use_esp() is False
    monkeypatch.setenv("SPHEREAI_AUDIO", "ESP")
    assert esp_audio.use_esp() is True


def test_voice_agent_listen_routes_to_esp(fake, monkeypatch):
    from agents.voice_agent import VoiceAgent

    esp = EspAudio(port=fake.name)
    monkeypatch.setenv("SPHEREAI_AUDIO", "esp")
    monkeypatch.setattr(esp_audio, "_instance", esp)
    y = VoiceAgent().listen(1.0)
    esp.close()
    assert y.shape == (16000,)


def test_speak_blocking_routes_to_esp(fake, monkeypatch, tmp_path):
    import sys
    import types

    import soundfile as sf
    from core import speech

    class Engine:
        def setProperty(self, *a):
            pass

        def save_to_file(self, text, path):
            t = np.arange(0, 0.5, 1 / 22050)
            sf.write(path, (0.3 * np.sin(2 * np.pi * 300 * t)).astype(np.float32), 22050)

        def runAndWait(self):
            pass

    stub = types.SimpleNamespace(init=lambda: Engine())
    monkeypatch.setitem(sys.modules, "pyttsx3", stub)
    esp = EspAudio(port=fake.name)
    monkeypatch.setenv("SPHEREAI_AUDIO", "esp")
    monkeypatch.setattr(esp_audio, "_instance", esp)
    speech.speak_blocking("hello")
    esp.close()
    assert len(fake.received_play) == 16000
