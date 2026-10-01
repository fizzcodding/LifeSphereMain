import numpy as np
from scipy.signal import butter, filtfilt, find_peaks


def _bandpass_ecg(signal: np.ndarray, fs: float) -> np.ndarray:
    low = 5.0 / (fs / 2.0)
    high = min(15.0, fs * 0.45) / (fs / 2.0)
    b, a = butter(4, [low, high], btype='band')
    return filtfilt(b, a, signal)


def _derivative_filter(signal: np.ndarray, fs: float) -> np.ndarray:
    dt = 1.0 / fs
    deriv = np.gradient(signal, dt)
    return deriv


def _square(signal: np.ndarray) -> np.ndarray:
    return signal ** 2


def _moving_window_integrate(signal: np.ndarray, fs: float, window_ms: float = 150.0) -> np.ndarray:
    window_n = max(1, int((window_ms / 1000.0) * fs))
    kernel = np.ones(window_n) / window_n
    return np.convolve(signal, kernel, mode='same')


def detect_ecg_r_peaks(
    ecg_signal: np.ndarray,
    fs: float = 500.0,
    min_rr_ms: float = 300.0,
    max_rr_ms: float = 2000.0,
    threshold_fraction: float = 0.3,
) -> np.ndarray:
    """
    Pan-Tompkins-style R-peak detector for AD8232 ECG signals.

    Pipeline: bandpass (5-15 Hz) -> differentiate -> square ->
              moving-window integrate -> adaptive threshold peak detection.

    Parameters
    ----------
    ecg_signal : raw ECG ADC samples (mV or raw counts, scale-invariant)
    fs : sampling rate in Hz (AD8232 typical: 200-500 Hz)
    min_rr_ms : minimum physiological RR interval (300 ms => max ~200 bpm)
    max_rr_ms : maximum physiological RR interval (2000 ms => min 30 bpm)
    threshold_fraction : fraction of signal envelope used as detection threshold

    Returns
    -------
    r_peak_indices : array of sample indices corresponding to R-peak locations
    """
    if len(ecg_signal) < int(fs * 1.5):
        return np.array([], dtype=int)

    filtered = _bandpass_ecg(ecg_signal, fs)
    deriv = _derivative_filter(filtered, fs)
    squared = _square(deriv)
    integrated = _moving_window_integrate(squared, fs, window_ms=150.0)

    min_distance = int((min_rr_ms / 1000.0) * fs)
    threshold = threshold_fraction * np.max(integrated)

    candidate_peaks, props = find_peaks(
        integrated,
        distance=min_distance,
        height=threshold,
    )

    if len(candidate_peaks) == 0:
        return np.array([], dtype=int)

    search_radius = int(0.05 * fs)
    r_peaks = []
    for cp in candidate_peaks:
        lo = max(0, cp - search_radius)
        hi = min(len(filtered), cp + search_radius + 1)
        segment = filtered[lo:hi]
        local_max = lo + int(np.argmax(np.abs(segment)))
        r_peaks.append(local_max)

    r_peaks = np.array(sorted(set(r_peaks)), dtype=int)

    if len(r_peaks) < 2:
        return r_peaks

    rr_samples = np.diff(r_peaks)
    rr_ms = (rr_samples / fs) * 1000.0
    valid_mask = (rr_ms >= min_rr_ms) & (rr_ms <= max_rr_ms)
    keep = np.concatenate([[True], valid_mask])
    r_peaks = r_peaks[keep]

    return r_peaks


def extract_rr_from_ecg(
    ecg_signal: np.ndarray,
    fs: float = 500.0,
    artifact_threshold: float = 0.25,
) -> np.ndarray:
    """
    Detect R-peaks and return cleaned RR intervals in milliseconds.

    Artifact removal uses the same ectopic beat filter as ppg_peaks:
    RR intervals deviating more than artifact_threshold*100% from the
    local median are dropped.

    Returns
    -------
    rr_ms : cleaned RR interval array in milliseconds
    """
    r_peaks = detect_ecg_r_peaks(ecg_signal, fs)
    if len(r_peaks) < 2:
        return np.array([])

    rr_samples = np.diff(r_peaks)
    rr_ms = (rr_samples / fs) * 1000.0

    physiological_mask = (rr_ms >= 300.0) & (rr_ms <= 2000.0)
    rr_ms = rr_ms[physiological_mask]

    if len(rr_ms) < 2:
        return rr_ms

    median_rr = np.median(rr_ms)
    clean_mask = np.abs(rr_ms - median_rr) < (artifact_threshold * median_rr)
    return rr_ms[clean_mask]


def ecg_signal_quality(
    ecg_signal: np.ndarray,
    fs: float = 500.0,
) -> dict:
    """
    Compute basic signal quality metrics for an ECG segment.

    SNR is estimated as peak amplitude versus inter-peak baseline RMS,
    not as filter residual (bandpass residual is not a valid noise proxy
    for broadband R-peak spikes).

    Returns dict with: snr_db, peak_count, mean_hr_bpm, quality_ok.
    quality_ok is True when peak_count >= 4, SNR > 6 dB, and HR is
    physiologically plausible (30-200 bpm).
    """
    if len(ecg_signal) < int(fs * 2):
        return {'snr_db': 0.0, 'peak_count': 0, 'mean_hr_bpm': 0.0, 'quality_ok': False}

    r_peaks = detect_ecg_r_peaks(ecg_signal, fs)
    peak_count = int(len(r_peaks))

    if peak_count >= 2:
        duration_s = len(ecg_signal) / fs
        mean_hr_bpm = float((peak_count - 1) / duration_s * 60.0)
    else:
        mean_hr_bpm = 0.0

    if peak_count >= 2:
        peak_amplitudes = np.abs(ecg_signal[r_peaks])
        search_r = int(0.04 * fs)
        baseline_samples = []
        for pk in r_peaks:
            mid_pre = max(0, pk - search_r * 3)
            baseline_samples.append(ecg_signal[mid_pre])
        baseline_rms = float(np.std(baseline_samples)) + 1e-12
        signal_rms = float(np.mean(peak_amplitudes))
        snr_db = float(20.0 * np.log10(signal_rms / baseline_rms))
    else:
        snr_db = 0.0

    quality_ok = (
        peak_count >= 4
        and snr_db > 6.0
        and 30.0 <= mean_hr_bpm <= 200.0
    )

    return {
        'snr_db': snr_db,
        'peak_count': peak_count,
        'mean_hr_bpm': mean_hr_bpm,
        'quality_ok': quality_ok,
    }
