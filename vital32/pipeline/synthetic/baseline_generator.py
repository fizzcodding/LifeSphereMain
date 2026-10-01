"""
SYNTHETIC DATA — NOT REAL USER DATA
All data produced by this module is procedurally generated from physiological
parameter distributions. It is suitable for pipeline testing, model architecture
validation, and demo purposes only. It is NOT suitable for clinical validation,
accuracy claims, or deployment without real 30-day baseline data collection.
"""

import numpy as np


FEATURE_COLUMNS = [
    'heart_rate',
    'spo2',
    'skin_temp',
    'hrv_rmssd',
    'hrv_lf_hf',
    'accel_mag',
    'gsr',
    'ambient_temp',
    'humidity',
    'pressure',
    'gas_resistance',
]


def _circadian_factor(hour: float) -> float:
    return 0.5 + 0.5 * np.cos(2 * np.pi * (hour - 14) / 24)


def generate_user_baseline(
    seed: int = 0,
    n_days: int = 30,
    samples_per_day: int = 2880,
    age: int = 70,
    resting_hr: float = 68.0,
    baseline_rmssd: float = 35.0,
) -> dict:
    rng = np.random.default_rng(seed)
    n_samples = n_days * samples_per_day
    hours = np.tile(np.linspace(0, 24, samples_per_day, endpoint=False), n_days)
    circadian = _circadian_factor(hours)
    sleep_mask = (hours >= 22) | (hours < 6)
    activity_mask = (hours >= 7) & (hours < 19)
    heart_rate = (
        resting_hr
        + 8.0 * circadian
        + rng.normal(0, 3.0, n_samples)
        + 20.0 * activity_mask * rng.random(n_samples) * 0.3
    )
    heart_rate = np.clip(heart_rate, 45, 110)
    spo2 = 98.0 - 0.5 * (age / 70.0) + rng.normal(0, 0.3, n_samples)
    spo2 = np.clip(spo2, 92, 100)
    skin_temp = (
        36.2
        + 0.5 * circadian
        + rng.normal(0, 0.15, n_samples)
        - 0.2 * sleep_mask
    )
    skin_temp = np.clip(skin_temp, 34.5, 38.5)
    hrv_rmssd = (
        baseline_rmssd
        - 8.0 * (heart_rate - resting_hr) / resting_hr
        + rng.normal(0, 5.0, n_samples)
        + 10.0 * sleep_mask
    )
    hrv_rmssd = np.clip(hrv_rmssd, 5.0, 120.0)
    hrv_lf_hf = (
        1.5
        + 0.8 * activity_mask
        - 0.5 * sleep_mask
        + rng.exponential(0.3, n_samples)
    )
    hrv_lf_hf = np.clip(hrv_lf_hf, 0.2, 6.0)
    accel_mag = (
        9.81
        + activity_mask * rng.exponential(2.0, n_samples)
        + rng.normal(0, 0.3, n_samples)
    )
    accel_mag = np.clip(accel_mag, 9.0, 25.0)
    gsr = (
        0.3
        + 0.2 * activity_mask
        + rng.exponential(0.05, n_samples)
    )
    gsr = np.clip(gsr, 0.05, 2.0)
    ambient_temp = 24.0 + 3.0 * np.sin(2 * np.pi * hours / 24) + rng.normal(0, 0.5, n_samples)
    humidity = 55.0 + 10.0 * np.sin(2 * np.pi * hours / 24) + rng.normal(0, 2.0, n_samples)
    humidity = np.clip(humidity, 20.0, 90.0)
    pressure = 1013.0 + rng.normal(0, 1.5, n_samples)
    gas_resistance = 50000.0 + rng.normal(0, 5000.0, n_samples)
    gas_resistance = np.clip(gas_resistance, 10000.0, 200000.0)
    features = np.column_stack([
        heart_rate, spo2, skin_temp, hrv_rmssd, hrv_lf_hf,
        accel_mag, gsr, ambient_temp, humidity, pressure, gas_resistance,
    ])
    timestamps = np.arange(n_samples) * (86400.0 / samples_per_day)
    return {
        'features': features,
        'feature_columns': FEATURE_COLUMNS,
        'timestamps': timestamps,
        'n_days': n_days,
        'samples_per_day': samples_per_day,
        'user_seed': seed,
        'data_source': 'SYNTHETIC — not real user data',
    }


def generate_rolling_window_features(
    baseline: dict,
    window_seconds: int = 30,
    samples_per_day: int = 2880,
) -> np.ndarray:
    features = baseline['features']
    window_size = max(1, int(window_seconds * samples_per_day / 86400))
    n_windows = len(features) - window_size + 1
    windows = np.lib.stride_tricks.sliding_window_view(features, (window_size, features.shape[1]))
    windows = windows.reshape(n_windows, window_size, features.shape[1])
    return windows.mean(axis=1)
