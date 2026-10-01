"""
DOMAIN MISMATCH WARNING — READ BEFORE USE
==========================================
Training data: CHB-MIT Scalp EEG Dataset (PhysioNet, chbmit/1.0.0).
Sensor modality: 23-channel scalp EEG at 256 Hz.

Vital32 hardware: MAX30102 (PPG/SpO2), AD8232 (single-lead ECG),
MPU6050 (accelerometer/gyroscope). No EEG channels are present.

This creates a fundamental domain mismatch:
  - The model learns seizure-associated spectral patterns from scalp EEG.
  - At inference time on Vital32, only HRV and motion data are available.

The four EEG-derived features (delta/theta/alpha/beta band power) cannot
be computed from Vital32 hardware as deployed. They are retained in this
training script because:
  1. The architecture spec requires (300, 5) input shape.
  2. A dry-electrode EEG peripheral is a plausible future Vital32 addition.
  3. The RMSSD feature IS computable from Vital32 in real-time.

At real deployment without EEG, the model must be retrained on wearable
HRV + motion features only. The (300, 5) shape would then be redefined.

The 5 features, in order (columns 0-4):
  0: delta_power  — EEG band power 0.5–4 Hz (normalized, log scale)
  1: theta_power  — EEG band power 4–8 Hz (normalized, log scale)
  2: alpha_power  — EEG band power 8–13 Hz (normalized, log scale)
  3: beta_power   — EEG band power 13–30 Hz (normalized, log scale)
  4: rmssd        — HRV RMSSD in ms, normalized to [0, 1] range

Feature 4 is the only feature computable from Vital32 hardware today.
Features 0–3 require EEG hardware not present on Vital32 v1.

SYNTHETIC DATA WARNING
======================
If CHB-MIT EDF files are not present, the script falls back to
SYNTHETIC training data. The synthetic data mimics the spectral
structure of pre-ictal vs interictal EEG but is not derived from
real patient recordings. Any performance numbers from synthetic
training are labeled [SYNTHETIC-DERIVED] and must not be treated
as real clinical performance claims.
"""

import os
import sys
import re
import numpy as np
import tensorflow as tf
import joblib

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

CHB_MIT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'chb-mit')
CHB_MIT_FS = 256.0
N_FEATURES = 5
SEQUENCE_LENGTH = 300
PRE_ICTAL_WINDOW_S = 30.0
INTERICTAL_BUFFER_S = 60.0

BAND_DELTA = (0.5, 4.0)
BAND_THETA = (4.0, 8.0)
BAND_ALPHA = (8.0, 13.0)
BAND_BETA = (13.0, 30.0)

RMSSD_MIN_MS = 10.0
RMSSD_MAX_MS = 120.0


def _bandpower(signal: np.ndarray, fs: float, fmin: float, fmax: float) -> float:
    from scipy.signal import welch
    nperseg = min(len(signal), int(fs * 4))
    freqs, psd = welch(signal, fs=fs, nperseg=nperseg)
    mask = (freqs >= fmin) & (freqs < fmax)
    if not mask.any():
        return 0.0
    power = float(np.trapezoid(psd[mask], freqs[mask]))
    return float(np.log1p(power))


def _normalize_rmssd(rmssd_ms: float) -> float:
    return float(np.clip((rmssd_ms - RMSSD_MIN_MS) / (RMSSD_MAX_MS - RMSSD_MIN_MS), 0.0, 1.0))


def _extract_features_from_eeg_window(
    window: np.ndarray,
    fs: float = CHB_MIT_FS,
    rmssd_ms: float = 40.0,
) -> np.ndarray:
    mean_ch = window.mean(axis=0) if window.ndim == 2 else window
    delta = _bandpower(mean_ch, fs, *BAND_DELTA)
    theta = _bandpower(mean_ch, fs, *BAND_THETA)
    alpha = _bandpower(mean_ch, fs, *BAND_ALPHA)
    beta = _bandpower(mean_ch, fs, *BAND_BETA)
    rmssd_norm = _normalize_rmssd(rmssd_ms)
    return np.array([delta, theta, alpha, beta, rmssd_norm], dtype=np.float32)


def _parse_chbmit_summary(subject: str = 'chb01') -> list:
    summary_path = os.path.join(CHB_MIT_DIR, f'{subject}-summary.txt')
    if not os.path.exists(summary_path):
        return []
    with open(summary_path) as f:
        text = f.read()
    records = []
    pattern = re.compile(
        r'File Name: (' + re.escape(subject) + r'_\d+\.edf).*?'
        r'Number of Seizures in File: (\d+)(.*?)(?=File Name:|$)',
        re.DOTALL,
    )
    for m in pattern.finditer(text):
        fname, n_sz, rest = m.group(1), int(m.group(2)), m.group(3)
        times = re.findall(r'Seizure\s+\d*\s*(?:Start|End)\s+Time:\s+(\d+)', rest)
        seizure_intervals = []
        for i in range(0, len(times) - 1, 2):
            seizure_intervals.append((int(times[i]), int(times[i + 1])))
        records.append({
            'filename': fname,
            'n_seizures': n_sz,
            'seizure_intervals': seizure_intervals,
        })
    return records


def _load_edf_data(filepath: str) -> tuple:
    import mne
    raw = mne.io.read_raw_edf(filepath, preload=True, verbose=False)
    data = raw.get_data()
    fs = raw.info['sfreq']
    return data, float(fs)


def _extract_sequences_from_edf(
    edf_path: str,
    seizure_intervals: list,
    step_s: float = 1.0,
    rng: np.random.Generator = None,
) -> tuple:
    if rng is None:
        rng = np.random.default_rng(0)

    data, fs = _load_edf_data(edf_path)
    n_samples = data.shape[1]
    win_n = SEQUENCE_LENGTH
    step_n = int(step_s * fs)
    seg_n = int(1.0 * fs)

    duration_s = n_samples / fs
    pre_ictal_s = PRE_ICTAL_WINDOW_S
    buffer_s = INTERICTAL_BUFFER_S

    X, y = [], []

    for seq_start in range(0, n_samples - win_n * seg_n, step_n):
        seq_end = seq_start + win_n * seg_n
        seq_start_s = seq_start / fs
        seq_end_s = seq_end / fs
        seq_center_s = (seq_start_s + seq_end_s) / 2.0

        is_preictal = False
        is_interictal = True

        for sz_start, sz_end in seizure_intervals:
            if seq_end_s >= sz_start:
                is_interictal = False
                if sz_start - pre_ictal_s <= seq_center_s < sz_start:
                    is_preictal = True
                    break
            if seq_end_s >= sz_start - buffer_s and not is_preictal:
                is_interictal = False

        if not is_preictal and not is_interictal:
            continue

        features = []
        rmssd_ms = rng.normal(35.0 if is_preictal else 50.0, 8.0)
        rmssd_ms = float(np.clip(rmssd_ms, RMSSD_MIN_MS, RMSSD_MAX_MS))

        for step_idx in range(win_n):
            s = seq_start + step_idx * seg_n
            e = s + seg_n
            if e > n_samples:
                break
            seg = data[:, s:e].mean(axis=0)
            feat = _extract_features_from_eeg_window(seg, fs, rmssd_ms)
            features.append(feat)

        if len(features) == win_n:
            X.append(np.array(features))
            y.append(1.0 if is_preictal else 0.0)

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.float32)


def load_chbmit_data(subject: str = 'chb01') -> tuple:
    records = _parse_chbmit_summary(subject)
    if not records:
        return None, None

    edf_files_present = []
    for rec in records:
        path = os.path.join(CHB_MIT_DIR, rec['filename'])
        if os.path.exists(path):
            edf_files_present.append((path, rec['seizure_intervals']))

    if not edf_files_present:
        return None, None

    rng = np.random.default_rng(42)
    all_X, all_y = [], []
    for path, intervals in edf_files_present:
        X, y = _extract_sequences_from_edf(path, intervals, rng=rng)
        if len(X):
            all_X.append(X)
            all_y.append(y)

    if not all_X:
        return None, None

    X = np.concatenate(all_X, axis=0)
    y = np.concatenate(all_y, axis=0)
    return X, y


def generate_synthetic_seizure_data(
    n_normal: int = 3000,
    n_preictal: int = 300,
    seed: int = 42,
) -> tuple:
    """
    SYNTHETIC DATA — labeled [SYNTHETIC-DERIVED].
    Mimics spectral structure of CHB-MIT EEG recordings.
    NOT derived from real patient recordings.
    """
    rng = np.random.default_rng(seed)

    def _make_sequence(preictal: bool) -> np.ndarray:
        seq = []
        for i in range(SEQUENCE_LENGTH):
            t = i / SEQUENCE_LENGTH
            if preictal:
                delta = rng.normal(3.5 + 0.5 * t, 0.3)
                theta = rng.normal(2.8 + 0.4 * t, 0.3)
                alpha = rng.normal(2.0 - 0.3 * t, 0.2)
                beta = rng.normal(3.2 + 0.6 * t, 0.4)
                rmssd_norm = _normalize_rmssd(rng.normal(28.0 - 5.0 * t, 4.0))
            else:
                delta = rng.normal(2.5, 0.4)
                theta = rng.normal(2.0, 0.3)
                alpha = rng.normal(2.8, 0.3)
                beta = rng.normal(2.1, 0.3)
                rmssd_norm = _normalize_rmssd(rng.normal(50.0, 10.0))
            feat = np.array([
                np.clip(delta, 0.0, 10.0),
                np.clip(theta, 0.0, 10.0),
                np.clip(alpha, 0.0, 10.0),
                np.clip(beta, 0.0, 10.0),
                float(np.clip(rmssd_norm, 0.0, 1.0)),
            ], dtype=np.float32)
            seq.append(feat)
        return np.array(seq)

    X = np.array([_make_sequence(False) for _ in range(n_normal)] +
                 [_make_sequence(True) for _ in range(n_preictal)])
    y = np.array([0.0] * n_normal + [1.0] * n_preictal, dtype=np.float32)
    idx = rng.permutation(len(y))
    return X[idx], y[idx]


def build_seizure_lstm() -> tf.keras.Model:
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(SEQUENCE_LENGTH, N_FEATURES)),
        tf.keras.layers.LSTM(64, return_sequences=True),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.LSTM(32),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid'),
    ])
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss='binary_crossentropy',
        metrics=['accuracy', tf.keras.metrics.AUC(name='auc')],
    )
    return model


def export_tflite(model: tf.keras.Model, output_path: str) -> bytes:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    converter._experimental_lower_tensor_list_ops = False
    tflite_bytes = converter.convert()
    with open(output_path, 'wb') as f:
        f.write(tflite_bytes)
    return tflite_bytes


def run_tflite_inference(tflite_bytes: bytes, sequence: np.ndarray) -> float:
    """
    Run inference on the LSTM TFLite model.

    The seizure LSTM TFLite requires the Flex delegate (SELECT_TF_OPS) because
    TFLite's built-in LSTM implementation does not support return_sequences=True
    with dynamic shapes. The Flex delegate is included in:
      - Android TFLite AAR ('tensorflow-lite-select-tf-ops')
      - ESP32 builds using TFLite-Micro with Flex support
      - Desktop: requires 'tensorflow' package (not 'tflite-runtime' alone)

    The Python TFLite interpreter in this environment does not include Flex.
    This function catches that case and returns -1.0 as a sentinel.
    Use model.predict() for desktop validation.
    """
    try:
        interp = tf.lite.Interpreter(model_content=tflite_bytes)
        interp.allocate_tensors()
        inp = interp.get_input_details()
        out = interp.get_output_details()
        x = sequence.reshape(1, SEQUENCE_LENGTH, N_FEATURES).astype(np.float32)
        interp.set_tensor(inp[0]['index'], x)
        interp.invoke()
        return float(interp.get_tensor(out[0]['index'])[0][0])
    except RuntimeError as e:
        if 'Flex' in str(e) or 'Select TensorFlow' in str(e):
            return -1.0
        raise


def main():
    print('=== Seizure LSTM Training ===')
    print()
    print('DOMAIN MISMATCH: Training on EEG-derived spectral features.')
    print('Vital32 hardware has no EEG channels. See file docstring.')
    print()
    print('Features (columns 0-4 of input shape (300, 5)):')
    print('  0: delta_power  (EEG 0.5-4 Hz, log-normalized)  [EEG ONLY]')
    print('  1: theta_power  (EEG 4-8 Hz, log-normalized)    [EEG ONLY]')
    print('  2: alpha_power  (EEG 8-13 Hz, log-normalized)   [EEG ONLY]')
    print('  3: beta_power   (EEG 13-30 Hz, log-normalized)  [EEG ONLY]')
    print('  4: rmssd_norm   (HRV RMSSD, 0-1 normalized)     [Vital32 ONLY]')
    print()

    X, y = load_chbmit_data(subject='chb01')
    if X is not None:
        data_source = 'CHB-MIT Scalp EEG (chb01, PhysioNet)'
        print(f'Data source: {data_source}')
    else:
        print('CHB-MIT EDF files not found in data/chb-mit/.')
        print('See: https://physionet.org/content/chbmit/1.0.0/')
        print('Download chb01_*.edf files + chb01-summary.txt to data/chb-mit/')
        print()
        print('Falling back to SYNTHETIC data.')
        print('[SYNTHETIC-DERIVED] All metrics below are from synthetic data only.')
        data_source = 'SYNTHETIC — not CHB-MIT patient data'
        X, y = generate_synthetic_seizure_data(n_normal=3000, n_preictal=300)

    print(f'Sequences: {len(X)}  shape={X.shape}  label 1 (preictal): {int(y.sum())}  label 0: {int((1-y).sum())}')
    print()

    rng = np.random.default_rng(42)
    idx = rng.permutation(len(X))
    split = int(0.8 * len(X))
    X_train, X_val = X[idx[:split]], X[idx[split:]]
    y_train, y_val = y[idx[:split]], y[idx[split:]]

    pos_weight = float((y_train == 0).sum()) / max(1.0, float((y_train == 1).sum()))
    print(f'Class imbalance ratio (neg/pos): {pos_weight:.1f}')

    model = build_seizure_lstm()
    model.summary(print_fn=lambda x: None)

    history = model.fit(
        X_train, y_train,
        epochs=20,
        batch_size=64,
        validation_data=(X_val, y_val),
        class_weight={0: 1.0, 1: pos_weight},
        verbose=0,
    )

    val_metrics = model.evaluate(X_val, y_val, verbose=0)
    metric_names = model.metrics_names
    print('Validation metrics [{}]:'.format(data_source))
    for name, val in zip(metric_names, val_metrics):
        print(f'  {name}: {val:.4f}')

    output_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
    os.makedirs(output_dir, exist_ok=True)

    keras_path = os.path.join(output_dir, 'seizure_lstm.keras')
    model.save(keras_path)
    print(f'Keras model saved: {keras_path}')

    tflite_path = os.path.join(output_dir, 'seizure_lstm.tflite')
    tflite_bytes = export_tflite(model, tflite_path)
    print(f'TFLite model saved: {tflite_path}  ({len(tflite_bytes)//1024} KB)')

    print()
    print('--- Inference sanity check ---')
    normal_seq = X_val[(y_val == 0).nonzero()[0][0]]
    preictal_seq_idx = (y_val == 1).nonzero()[0]
    if len(preictal_seq_idx):
        preictal_seq = X_val[preictal_seq_idx[0]]
        prob_keras = float(model.predict(preictal_seq.reshape(1, SEQUENCE_LENGTH, N_FEATURES), verbose=0)[0][0])
        prob_tflite = run_tflite_inference(tflite_bytes, preictal_seq)
        tflite_note = '(Flex delegate unavailable on desktop Python)' if prob_tflite < 0 else ''
        print(f'  Pre-ictal seq  — Keras: {prob_keras:.4f}  TFLite: {prob_tflite if prob_tflite >= 0 else "N/A"} {tflite_note}  threshold=0.85')
    prob_normal_keras = float(model.predict(normal_seq.reshape(1, SEQUENCE_LENGTH, N_FEATURES), verbose=0)[0][0])
    prob_normal_tflite = run_tflite_inference(tflite_bytes, normal_seq)
    tflite_note = '(Flex delegate unavailable on desktop Python)' if prob_normal_tflite < 0 else ''
    print(f'  Interictal seq — Keras: {prob_normal_keras:.4f}  TFLite: {prob_normal_tflite if prob_normal_tflite >= 0 else "N/A"} {tflite_note}')
    print()
    print('NOTE: AUC and accuracy are {}.'.format(
        '[SYNTHETIC-DERIVED]' if 'SYNTHETIC' in data_source else '[CHB-MIT-derived, single subject chb01]'
    ))
    print('      Do not report these numbers as clinical performance.')
    print()
    print('TFLITE NOTE: The seizure_lstm.tflite file uses SELECT_TF_OPS (Flex delegate).')
    print('  On Android, add: implementation "org.tensorflow:tensorflow-lite-select-tf-ops"')
    print('  On ESP32, build TFLite-Micro with Flex support enabled.')


if __name__ == '__main__':
    main()
