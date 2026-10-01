import numpy as np
from scipy.signal import butter, filtfilt, find_peaks


def bandpass_filter(signal: np.ndarray, fs: float, lowcut: float = 0.5, highcut: float = 4.0) -> np.ndarray:
    nyq = fs / 2.0
    low = lowcut / nyq
    high = highcut / nyq
    b, a = butter(4, [low, high], btype='band')
    return filtfilt(b, a, signal)


def detect_ppg_peaks(ppg_signal: np.ndarray, fs: float = 25.0) -> np.ndarray:
    filtered = bandpass_filter(ppg_signal, fs)
    min_distance = int(fs * 0.35)
    min_height = np.mean(filtered) + 0.3 * np.std(filtered)
    peaks, _ = find_peaks(filtered, distance=min_distance, height=min_height)
    return peaks


def extract_rr_intervals(ppg_signal: np.ndarray, fs: float = 25.0) -> np.ndarray:
    peaks = detect_ppg_peaks(ppg_signal, fs)
    if len(peaks) < 2:
        return np.array([])
    rr_samples = np.diff(peaks)
    rr_ms = (rr_samples / fs) * 1000.0
    physiological_mask = (rr_ms >= 300) & (rr_ms <= 2000)
    rr_ms = rr_ms[physiological_mask]
    if len(rr_ms) < 2:
        return rr_ms
    median_rr = np.median(rr_ms)
    artifact_mask = np.abs(rr_ms - median_rr) < (0.25 * median_rr)
    return rr_ms[artifact_mask]


def instantaneous_heart_rate(rr_ms: np.ndarray) -> float:
    if len(rr_ms) == 0:
        return 0.0
    return float(60000.0 / np.mean(rr_ms))
