import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pipeline.signal_processing import (
    detect_ppg_peaks, extract_rr_intervals, instantaneous_heart_rate,
    compute_rmssd, compute_lf_hf_ratio, compute_hrv_features,
    compute_spo2, compute_spo2_windowed,
    detect_ecg_r_peaks, extract_rr_from_ecg, ecg_signal_quality,
)
from pipeline.signal_processing.spo2 import _generate_synthetic_ppg

PASS = '\033[92mPASS\033[0m'
FAIL = '\033[91mFAIL\033[0m'


def check(name: str, condition: bool, detail: str = '') -> bool:
    status = PASS if condition else FAIL
    detail_str = f'  ({detail})' if detail else ''
    print(f'  [{status}] {name}{detail_str}')
    return condition


def test_ppg_peak_detection():
    print('\n--- PPG peak detection ---')
    rng = np.random.default_rng(0)
    fs = 25.0
    duration = 60.0
    hr_bpm = 72.0
    t = np.linspace(0, duration, int(duration * fs), endpoint=False)
    ppg = np.sin(2 * np.pi * hr_bpm / 60 * t) + 0.2 * np.sin(4 * np.pi * hr_bpm / 60 * t)
    ppg += rng.normal(0, 0.05, len(t))

    peaks = detect_ppg_peaks(ppg, fs)
    rr = extract_rr_intervals(ppg, fs)
    hr_est = instantaneous_heart_rate(rr)

    expected_peaks = int(hr_bpm * duration / 60)
    ok = True
    ok &= check('Peak count in plausible range',
                abs(len(peaks) - expected_peaks) <= 5,
                f'got {len(peaks)}, expected ~{expected_peaks}')
    ok &= check('RR intervals non-empty', len(rr) > 0,
                f'got {len(rr)} intervals')
    ok &= check('RR mean physiologically plausible',
                750 < rr.mean() < 900,
                f'{rr.mean():.1f} ms (expected ~833 ms for 72 bpm)')
    ok &= check('Estimated HR plausible',
                65 <= hr_est <= 80,
                f'{hr_est:.1f} bpm')
    return ok


def test_hrv_features():
    print('\n--- HRV feature extraction ---')
    rng = np.random.default_rng(1)
    rr_ms = np.clip(rng.normal(850, 30, 200), 400, 1500)
    feats = compute_hrv_features(rr_ms)
    rmssd = compute_rmssd(rr_ms)
    lf_hf = compute_lf_hf_ratio(rr_ms)

    ok = True
    ok &= check('RMSSD matches compute_hrv_features output',
                abs(feats['rmssd'] - rmssd) < 0.01,
                f'feats={feats["rmssd"]:.2f} direct={rmssd:.2f}')
    ok &= check('RMSSD physiologically plausible',
                5 < rmssd < 200,
                f'{rmssd:.1f} ms')
    ok &= check('Heart rate from RR plausible',
                50 < feats['heart_rate'] < 100,
                f'{feats["heart_rate"]:.1f} bpm')
    ok &= check('LF/HF ratio positive', lf_hf >= 0,
                f'{lf_hf:.3f}')
    ok &= check('SDNN positive', feats['sdnn'] > 0,
                f'{feats["sdnn"]:.2f} ms')

    rr_short = rr_ms[:1]
    ok &= check('RMSSD returns 0 with <2 intervals',
                compute_rmssd(rr_short) == 0.0, 'edge case')
    return ok


def test_spo2():
    print('\n--- SpO2 derivation ---')
    rng = np.random.default_rng(2)
    fs = 25.0
    duration = 30.0

    ir = _generate_synthetic_ppg(duration, fs, hr_bpm=70,
                                  dc_level=50000, ac_fraction=0.02,
                                  noise_std=50, rng=rng)
    red_normal = _generate_synthetic_ppg(duration, fs, hr_bpm=70,
                                          dc_level=30000, ac_fraction=0.01,
                                          noise_std=30, rng=rng)
    red_low = _generate_synthetic_ppg(duration, fs, hr_bpm=70,
                                       dc_level=30000, ac_fraction=0.028,
                                       noise_std=30, rng=rng)

    spo2_n, r_n, ok_n = compute_spo2(ir, red_normal, fs)
    spo2_l, r_l, ok_l = compute_spo2(ir, red_low, fs)
    spo2_s, _, ok_s = compute_spo2(ir[:10], red_normal[:10], fs)

    windowed = compute_spo2_windowed(ir, red_normal, fs)

    ok = True
    ok &= check('Normal SpO2 in healthy range',
                90 <= spo2_n <= 100,
                f'{spo2_n:.1f}%')
    ok &= check('Normal SpO2 quality flag True', ok_n)
    ok &= check('Low SpO2 < normal SpO2',
                spo2_l < spo2_n,
                f'{spo2_l:.1f}% < {spo2_n:.1f}%')
    ok &= check('Short signal quality flag False', not ok_s, 'edge case')
    ok &= check('Windowed output correct shape',
                windowed.ndim == 2 and windowed.shape[1] == 3,
                f'shape={windowed.shape}')
    ok &= check('Windowed SpO2 values in range',
                np.all((windowed[:, 0] >= 70) & (windowed[:, 0] <= 100)),
                f'range=[{windowed[:,0].min():.1f}, {windowed[:,0].max():.1f}]')
    return ok


def test_ecg_peaks():
    print('\n--- ECG/AD8232 R-peak detection ---')
    rng = np.random.default_rng(3)
    fs = 500.0
    duration = 60.0
    hr_bpm = 75.0
    t = np.linspace(0, duration, int(duration * fs), endpoint=False)
    freq = hr_bpm / 60.0

    ecg_clean = (
        1.0 * np.exp(-((t % (1 / freq)) - 0.3) ** 2 / 0.0005)
        - 0.3 * np.exp(-((t % (1 / freq)) - 0.25) ** 2 / 0.002)
        + 0.1 * np.sin(2 * np.pi * freq * t)
        + rng.normal(0, 0.05, len(t))
    )
    ecg_noisy = ecg_clean + rng.normal(0, 2.5, len(t))

    r_peaks = detect_ecg_r_peaks(ecg_clean, fs)
    rr_ms = extract_rr_from_ecg(ecg_clean, fs)
    quality_clean = ecg_signal_quality(ecg_clean, fs)
    quality_noisy = ecg_signal_quality(ecg_noisy, fs)
    rr_short = extract_rr_from_ecg(ecg_clean[:100], fs)

    expected_peaks = int(hr_bpm * duration / 60)
    ok = True
    ok &= check('R-peak count matches expected',
                abs(len(r_peaks) - expected_peaks) <= 3,
                f'got {len(r_peaks)}, expected ~{expected_peaks}')
    ok &= check('RR mean matches expected period',
                abs(rr_ms.mean() - 800.0) < 10.0,
                f'{rr_ms.mean():.1f} ms (expected 800 ms)')
    ok &= check('Clean ECG quality_ok True',
                quality_clean['quality_ok'],
                f'SNR={quality_clean["snr_db"]:.1f} dB')
    ok &= check('Noisy ECG quality_ok False',
                not quality_noisy['quality_ok'],
                f'SNR={quality_noisy["snr_db"]:.1f} dB')
    ok &= check('Short ECG returns empty RR',
                len(rr_short) == 0, 'edge case')
    return ok


def main():
    print('=== Signal Processing Test Suite ===')
    print('Inputs: synthetic signals — no real hardware data')

    results = [
        test_ppg_peak_detection(),
        test_hrv_features(),
        test_spo2(),
        test_ecg_peaks(),
    ]

    n_pass = sum(results)
    n_total = len(results)
    print(f'\nTest groups: {n_pass}/{n_total} passed')
    if not all(results):
        sys.exit(1)


if __name__ == '__main__':
    main()
