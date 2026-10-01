import numpy as np
from scipy.signal import butter, filtfilt
from .ppg_peaks import bandpass_filter, detect_ppg_peaks


def _remove_dc(signal: np.ndarray, fs: float) -> tuple:
    b, a = butter(2, 0.5 / (fs / 2), btype='high')
    ac = filtfilt(b, a, signal)
    dc = signal - ac
    dc_mean = float(np.mean(dc))
    return ac, dc_mean


def _ac_amplitude(ac_signal: np.ndarray, peaks: np.ndarray, fs: float) -> float:
    if len(peaks) < 2:
        return float(np.std(ac_signal))
    amplitudes = []
    for i in range(len(peaks) - 1):
        segment = ac_signal[peaks[i]:peaks[i + 1]]
        if len(segment) > 2:
            amplitudes.append(float(np.max(segment) - np.min(segment)))
    if not amplitudes:
        return float(np.std(ac_signal))
    return float(np.median(amplitudes))


def compute_spo2(
    ir_signal: np.ndarray,
    red_signal: np.ndarray,
    fs: float = 25.0,
    a_coeff: float = 110.0,
    b_coeff: float = 25.0,
) -> tuple:
    """
    Compute SpO2 from raw MAX30102 IR and Red PPG signals using Beer-Lambert
    ratio-of-ratios method.

    SpO2 = a - b * R
    where R = (AC_red / DC_red) / (AC_ir / DC_ir)

    Default calibration coefficients (a=110, b=25) are the empirical
    Maxim Integrated reference values. Real devices require per-unit
    calibration against a pulse oximeter reference.

    Returns:
        (spo2_percent, r_ratio, quality_flag)
        quality_flag: True when the signal quality is sufficient for a
                      reliable estimate.
    """
    if len(ir_signal) != len(red_signal):
        raise ValueError('IR and Red signals must be the same length.')
    if len(ir_signal) < int(fs * 4):
        return 0.0, 0.0, False

    ir_filtered = bandpass_filter(ir_signal, fs, lowcut=0.5, highcut=4.0)
    red_filtered = bandpass_filter(red_signal, fs, lowcut=0.5, highcut=4.0)

    ir_ac, ir_dc = _remove_dc(ir_signal, fs)
    red_ac, red_dc = _remove_dc(red_signal, fs)

    if ir_dc < 1e-6 or red_dc < 1e-6:
        return 0.0, 0.0, False

    peaks = detect_ppg_peaks(ir_filtered, fs)

    ir_ac_amp = _ac_amplitude(ir_ac, peaks, fs)
    red_ac_amp = _ac_amplitude(red_ac, peaks, fs)

    ir_perfusion = ir_ac_amp / ir_dc
    red_perfusion = red_ac_amp / red_dc

    if ir_perfusion < 1e-6:
        return 0.0, 0.0, False

    r_ratio = red_perfusion / ir_perfusion

    spo2 = a_coeff - b_coeff * r_ratio
    spo2 = float(np.clip(spo2, 70.0, 100.0))

    quality_flag = (
        len(peaks) >= 4
        and ir_perfusion > 0.001
        and 0.4 <= r_ratio <= 3.5
    )

    return spo2, float(r_ratio), quality_flag


def compute_spo2_windowed(
    ir_signal: np.ndarray,
    red_signal: np.ndarray,
    fs: float = 25.0,
    window_s: float = 8.0,
    step_s: float = 2.0,
    a_coeff: float = 110.0,
    b_coeff: float = 25.0,
) -> np.ndarray:
    """
    Compute SpO2 over sliding windows. Returns array of shape (N, 3):
    columns are [spo2, r_ratio, quality_flag_int].
    """
    window_n = int(window_s * fs)
    step_n = int(step_s * fs)
    results = []
    pos = 0
    while pos + window_n <= len(ir_signal):
        ir_win = ir_signal[pos:pos + window_n]
        red_win = red_signal[pos:pos + window_n]
        spo2, r, quality = compute_spo2(ir_win, red_win, fs, a_coeff, b_coeff)
        results.append([spo2, r, float(quality)])
        pos += step_n
    if not results:
        return np.empty((0, 3))
    return np.array(results)


def _generate_synthetic_ppg(
    duration_s: float,
    fs: float,
    hr_bpm: float,
    dc_level: float,
    ac_fraction: float,
    noise_std: float,
    rng: np.random.Generator,
) -> np.ndarray:
    t = np.linspace(0, duration_s, int(duration_s * fs), endpoint=False)
    freq = hr_bpm / 60.0
    ppg = dc_level + dc_level * ac_fraction * (
        np.sin(2 * np.pi * freq * t)
        + 0.15 * np.sin(4 * np.pi * freq * t)
        + 0.05 * np.sin(6 * np.pi * freq * t)
    )
    ppg += rng.normal(0, noise_std, len(t))
    return ppg
