import os
import threading
import time

import numpy as np
import serial
from serial.tools import list_ports

SAMPLE_RATE = 16000
BAUD = 921600
CHUNK = 1024
WINDOW = 4
_CANDIDATE_VIDS = (0x303A, 0x10C4, 0x1A86)


class EspAudioError(RuntimeError):
    pass


def use_esp() -> bool:
    return os.getenv("SPHEREAI_AUDIO", "laptop").strip().lower() == "esp"


def find_port() -> str:
    env = os.getenv("ESP_AUDIO_PORT")
    if env:
        return env
    candidates = [p.device for p in list_ports.comports() if p.vid in _CANDIDATE_VIDS]
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        raise EspAudioError("No ESP32 serial port found. Set ESP_AUDIO_PORT.")
    raise EspAudioError(
        f"Several ESP32-like ports found {candidates}. Set ESP_AUDIO_PORT to the audio board."
    )


class EspAudio:
    def __init__(self, port: str | None = None, baud: int = BAUD):
        name = port or find_port()
        self._lock = threading.RLock()
        self._mic_gain = float(os.getenv("ESP_MIC_GAIN", "1.0"))
        self._spk_volume = float(os.getenv("ESP_SPK_VOLUME", "0.8"))
        ser = serial.Serial()
        ser.port = name
        ser.baudrate = baud
        ser.timeout = 0.5
        ser.write_timeout = 5
        ser.dtr = False
        ser.rts = False
        ser.open()
        self._ser = ser
        self._port_name = name
        self._sync()

    @property
    def port(self) -> str:
        return self._port_name

    def _readline(self, timeout: float = 1.0):
        buf = bytearray()
        end = time.time() + timeout
        while time.time() < end:
            b = self._ser.read(1)
            if not b:
                continue
            if b == b"\n":
                return bytes(buf).strip()
            buf += b
        return None

    def _expect(self, prefix: bytes, timeout: float) -> bytes:
        end = time.time() + timeout
        while time.time() < end:
            line = self._readline(timeout=max(0.05, end - time.time()))
            if line is None:
                continue
            line = line.lstrip(b"K")
            if line.startswith(prefix):
                return line
            if line.startswith(b"ERR"):
                raise EspAudioError(line.decode(errors="replace"))
        raise EspAudioError(f"Timed out waiting for {prefix!r} from ESP32-S3")

    def _read_exact(self, n: int, timeout: float) -> bytes:
        buf = bytearray()
        end = time.time() + timeout
        while len(buf) < n:
            if time.time() > end:
                raise EspAudioError(f"Timed out reading audio ({len(buf)} of {n} bytes)")
            want = min(max(self._ser.in_waiting, 1), n - len(buf))
            chunk = self._ser.read(want)
            if chunk:
                buf += chunk
        return bytes(buf)

    def _sync(self, timeout: float = 8.0) -> None:
        end = time.time() + timeout
        while time.time() < end:
            self._ser.reset_input_buffer()
            self._ser.write(b"PING\n")
            t_end = time.time() + 1.0
            while time.time() < t_end:
                line = self._readline(timeout=0.3)
                if line is not None and line.startswith(b"PONG"):
                    return
        raise EspAudioError(
            f"ESP32-S3 audio firmware did not answer PING on {self._port_name}"
        )

    def record(self, seconds: float = 6.0) -> np.ndarray:
        ms = int(seconds * 1000)
        with self._lock:
            self._ser.reset_input_buffer()
            self._ser.write(f"REC {ms}\n".encode())
            header = self._expect(b"AUD ", 5.0)
            try:
                nbytes = int(header.split()[1])
            except (IndexError, ValueError):
                raise EspAudioError(f"Bad header from device: {header!r}")
            data = self._read_exact(nbytes, seconds + 5.0)
            self._expect(b"OK", 3.0)
        data = data[: len(data) // 2 * 2]
        pcm = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0
        pcm = pcm - float(np.mean(pcm))
        return np.clip(pcm * self._mic_gain, -1.0, 1.0).astype(np.float32)

    def play(self, y: np.ndarray, sr: int = SAMPLE_RATE) -> None:
        y = np.asarray(y, dtype=np.float32)
        if y.ndim > 1:
            y = y.mean(axis=1)
        if sr != SAMPLE_RATE:
            import librosa

            y = librosa.resample(y, orig_sr=sr, target_sr=SAMPLE_RATE)
        pcm = (np.clip(y * self._spk_volume, -1.0, 1.0) * 32767).astype("<i2").tobytes()
        total = len(pcm)
        if total == 0:
            return
        with self._lock:
            self._ser.reset_input_buffer()
            self._ser.write(f"PLAY {total}\n".encode())
            self._expect(b"RDY", 3.0)
            sent = 0
            chunks = 0
            acked = 0
            last_progress = time.time()
            while sent < total:
                while chunks - acked >= WINDOW:
                    got = self._ser.read(max(1, self._ser.in_waiting))
                    if got:
                        if b"ERR" in got:
                            raise EspAudioError("Device reported an error during playback")
                        acked += got.count(b"K")
                        last_progress = time.time()
                    elif time.time() - last_progress > 5.0:
                        raise EspAudioError("Playback stalled")
                piece = pcm[sent : sent + CHUNK]
                self._ser.write(piece)
                sent += len(piece)
                chunks += 1
            self._expect(b"DONE", 5.0 + total / 32000.0)

    def wait_button(self, timeout: float | None = None) -> bool:
        with self._lock:
            self._ser.reset_input_buffer()
            end = None if timeout is None else time.time() + timeout
            while end is None or time.time() < end:
                line = self._readline(timeout=0.5)
                if line and line.lstrip(b"K").startswith(b"EVT BTN"):
                    return True
            return False

    def close(self) -> None:
        with self._lock:
            if self._ser.is_open:
                self._ser.close()


_instance = None
_instance_lock = threading.Lock()


def get_esp() -> EspAudio:
    global _instance
    with _instance_lock:
        if _instance is None:
            _instance = EspAudio()
        return _instance
