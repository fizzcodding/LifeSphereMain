import numpy as np
from scipy.signal import welch
from scipy.interpolate import interp1d


def compute_rmssd(rr_ms: np.ndarray) -> float:
    if len(rr_ms) < 2:
        return 0.0
    successive_diffs = np.diff(rr_ms)
    return float(np.sqrt(np.mean(successive_diffs ** 2)))


def compute_lf_hf_ratio(rr_ms: np.ndarray, fs_resample: float = 4.0) -> float:
    if len(rr_ms) < 10:
        return 0.0
    rr_s = rr_ms / 1000.0
    cumulative_time = np.cumsum(rr_s)
    cumulative_time = np.insert(cumulative_time, 0, 0)[:-1]
    total_duration = cumulative_time[-1]
    if total_duration < 30.0:
        return 0.0
    t_uniform = np.arange(0, total_duration, 1.0 / fs_resample)
    interpolator = interp1d(cumulative_time, rr_s, kind='cubic', fill_value='extrapolate')
    rr_uniform = interpolator(t_uniform)
    rr_uniform -= np.mean(rr_uniform)
    nperseg = min(len(rr_uniform), int(fs_resample * 60))
    freqs, psd = welch(rr_uniform, fs=fs_resample, nperseg=nperseg)
    lf_mask = (freqs >= 0.04) & (freqs < 0.15)
    hf_mask = (freqs >= 0.15) & (freqs < 0.40)
    lf_power = np.trapezoid(psd[lf_mask], freqs[lf_mask])
    hf_power = np.trapezoid(psd[hf_mask], freqs[hf_mask])
    if hf_power < 1e-12:
        return 0.0
    return float(lf_power / hf_power)


def compute_hrv_features(rr_ms: np.ndarray) -> dict:
    rmssd = compute_rmssd(rr_ms)
    lf_hf = compute_lf_hf_ratio(rr_ms)
    sdnn = float(np.std(rr_ms)) if len(rr_ms) >= 2 else 0.0
    mean_rr = float(np.mean(rr_ms)) if len(rr_ms) >= 1 else 0.0
    hr = float(60000.0 / mean_rr) if mean_rr > 0 else 0.0
    return {
        'rmssd': rmssd,
        'lf_hf_ratio': lf_hf,
        'sdnn': sdnn,
        'mean_rr_ms': mean_rr,
        'heart_rate': hr,
    }
