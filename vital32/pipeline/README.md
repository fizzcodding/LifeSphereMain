# Vital32 AI Model Training Pipeline

Offline model training and TFLite export pipeline for the Vital32 wearable biosensor node (LifeSphere project). Models are trained on a dev machine and deployed to the ESP32 WROOM-32 firmware.

## Quick start

```bash
cd vital32
python -m venv venv
source venv/bin/activate
pip install tensorflow scikit-learn xgboost scipy mne pyedflib joblib
```

Run all training scripts in order:

```bash
python pipeline/models/train_anomaly_forest.py
python pipeline/models/train_seizure_lstm.py
python pipeline/models/train_cortisol_estimator.py
python pipeline/models/train_bio_age_estimator.py
```

Run all tests:

```bash
python pipeline/tests/test_signal_processing.py
python pipeline/tests/test_anomaly_forest.py
python pipeline/tests/test_seizure_lstm.py
python pipeline/tests/test_cortisol.py
python pipeline/tests/test_bio_age.py
```

---

## What is demo-ready

These components run end to end and produce verified output:

**Signal processing layer** (`pipeline/signal_processing/`)
- PPG peak detection and RR interval extraction from MAX30102 raw IR signal (`ppg_peaks.py`). Bandpass 0.5–4 Hz, scipy `find_peaks`, physiological RR filter (300–2000 ms), ectopic beat artifact removal.
- HRV feature computation (`hrv_features.py`). RMSSD via `sqrt(mean(diff(RR)^2))`, LF/HF ratio via Welch PSD with cubic-spline RR interpolation at 4 Hz, LF 0.04–0.15 Hz, HF 0.15–0.40 Hz.
- SpO2 derivation from raw IR/Red PPG (`spo2.py`). Beer-Lambert ratio-of-ratios: `R = (AC_red/DC_red) / (AC_ir/DC_ir)`, `SpO2 = 110 − 25×R`. Maxim Integrated default coefficients. Includes per-beat AC amplitude estimation, signal quality flag, and sliding-window batch processing. Verified: normal scenario gives SpO2 97.1% with R≈0.52, as expected.
- ECG R-peak detection from AD8232 raw waveform (`ecg_peaks.py`). Pan-Tompkins-style: bandpass 5–15 Hz → differentiate → square → 150 ms moving-window integrate → adaptive threshold → local max refinement. Clean synthetic ECG at 75 bpm: 75 peaks detected, RR mean 800 ms, SNR 25.8 dB. Noisy signal correctly flagged quality_ok=False.

**Anomaly detector** — Isolation Forest, 100 trees, contamination=0.05
- Trained on synthetic 30-day per-user baseline (86,400 30-second rolling-window feature vectors, 11 features).
- Normalization calibrated from training data: `score = (df_max − df) / (df_max − df_min)` where df is `decision_function` output and bounds are the 1st/99th percentiles of training data. This fixed a bug in the previous version where all scores were near zero.
- Crisis sample (HR=145, SpO2=87, RMSSD=1.5) scores 1.0. Normal baseline median score ≈ 0.35. Alert rate on training data ≈ 6.4% at the 0.7 threshold (consistent with contamination=0.05).
- TFLite approximator: 4-layer Dense network trained to replicate IF scores. Exports to `models/anomaly_forest.tflite` (11 KB). TFLite inference verified on desktop Python.

**Cortisol estimator** — GradientBoostingRegressor, 200 trees
- Inputs: RMSSD (ms), GSR (µS), skin temperature (°C), sleep efficiency (0–1).
- Synthetic proxy: low-stress 2.4 ng/dL, high-stress 7.4 ng/dL, morning peak 20.1 ng/dL. Physiologically directionally correct.
- Saved as `models/cortisol_estimator.joblib` + `models/cortisol_scaler.joblib`.

**Biological age estimator** — RandomForest (200 trees) + XGBoost (200 trees) ensemble
- 11 input features spanning all sensor channels.
- Inference: healthy 65-year-old → 51 years estimated, deconditioned 72-year-old → 93 years estimated.
- Saved as `models/bio_age_rf.joblib`, `models/bio_age_xgb.joblib`, `models/bio_age_scaler.joblib`.

**Pre-seizure LSTM** — architecture as specified
- Input shape `(300, 5)`. Feature definitions: columns 0–3 are EEG band powers (delta, theta, alpha, beta, log-normalized); column 4 is HRV RMSSD (normalized to [0,1]).
- Architecture: `LSTM(64, return_sequences=True) → Dropout(0.3) → LSTM(32) → Dropout(0.3) → Dense(16, relu) → Dense(1, sigmoid)`.
- Keras model inference verified: pre-ictal sequence probability 1.0, interictal 0.0001 on synthetic data.
- TFLite export uses `SELECT_TF_OPS` (Flex delegate) because standard TFLite does not support `return_sequences=True` LSTM with dynamic shapes. File exports correctly (61 KB). On-device Android requires `org.tensorflow:tensorflow-lite-select-tf-ops` dependency. The Python desktop interpreter cannot run Flex-delegate TFLite models; this is expected and documented.

---

## What is synthetic-only

Every model in this pipeline was trained on procedurally generated data. No model has been validated on real user measurements.

**Anomaly Forest** — trained on synthetic 30-day baseline data from `pipeline/synthetic/baseline_generator.py`. The score distribution and threshold behavior is calibrated to synthetic physiological distributions. Retraining on 30 days of real per-user data will change the calibration constants and the alert rates.

**Cortisol Estimator** — no public wearable dataset pairs GSR/HRV/temperature readings with biochemically validated cortisol concentrations (ELISA or mass spectrometry). The proxy target is constructed from literature-derived direction-of-effect relationships (Thayer 2012, Nater 2006, Kudielka 2009, Vgontzas 1997). [SYNTHETIC-DERIVED] test MAE 1.85 ng/dL, R² 0.81 — these numbers measure proxy self-consistency, not clinical accuracy.

**Biological Age Estimator** — no public wearable dataset provides simultaneously collected sensor data and validated biological age labels (Horvath methylation clock, Levine PhenoAge, or equivalent). The proxy target adjusts chronological age by sensor-derived health indicators. [SYNTHETIC-DERIVED] ensemble MAE 3.6 years, R² 0.86 — same caveat.

**Pre-seizure LSTM** — see domain mismatch section below.

---

## Domain mismatch: seizure LSTM

**This is the most important limitation in the entire pipeline.**

The CHB-MIT Scalp EEG dataset (PhysioNet `chbmit/1.0.0`) provides 23-channel scalp EEG at 256 Hz from pediatric epilepsy patients. The model learns pre-ictal patterns from EEG spectral features.

Vital32 hardware has no EEG channels. The 16-sensor array includes MAX30102 (PPG/SpO2), AD8232 (single-lead ECG), MPU6050 (accelerometer), MLX90614 (skin temperature), BME688 (environmental), and GSR. None of these produce EEG-band spectral information.

Consequence: features 0–3 of the `(300, 5)` input (delta, theta, alpha, beta band power) cannot be computed from Vital32 in real-time. Only feature 4 (HRV RMSSD) is available from Vital32 hardware today.

The CHB-MIT EDF files were not downloaded during training (PhysioNet connection too slow for 42 MB files at ~35 KB/s). The model trained on synthetic data that mimics pre-ictal EEG spectral structure. All reported metrics are [SYNTHETIC-DERIVED].

**What would make this model clinically usable:**
1. A dry-electrode EEG peripheral added to Vital32 hardware (e.g., TGAM1 or Emotiv INSIGHT chip) — this is documented as a planned Vital32 v2 feature.
2. CHB-MIT EDF files downloaded and the real loader path exercised (`load_chbmit_data('chb01')`).
3. Retraining on real per-user HRV + EEG data.

The CHB-MIT loader code is fully implemented in `train_seizure_lstm.py`. Place EDF files in `data/chb-mit/` alongside the `chb01-summary.txt` that is already present, and rerun the script — it will automatically use real data instead of synthetic.

---

## What needs real user data before caregiving deployment

| Component | What it needs | Minimum viable dataset |
|---|---|---|
| Anomaly Forest | 30-day per-user baseline at 30s sampling | 86,400 samples per user |
| Cortisol Estimator | Simultaneous wearable + saliva samples (morning, noon, evening) | ≥50 users × 7 days |
| Biological Age Estimator | Validated biological age labels (DNA methylation or clinical composite) | Hundreds of users, longitudinal |
| Seizure LSTM | EEG peripheral hardware or wearable pre-ictal correlates dataset | CHB-MIT + dry-EEG peripheral |

None of the deployed `.joblib` or `.tflite` files are safe to use for clinical decision-making in their current state. The anomaly forest and cortisol estimator are the closest to production-ready once real user data is collected; both have well-defined data collection requirements and no missing hardware dependencies.

---

## Repository layout

```
vital32/
├── models/                          # Trained model artifacts
│   ├── anomaly_forest.joblib        # Isolation Forest (sklearn)
│   ├── anomaly_scaler.joblib        # StandardScaler for IF
│   ├── anomaly_calibration.joblib   # df_min/df_max normalization bounds
│   ├── anomaly_forest.tflite        # TFLite approximator (11 KB)
│   ├── seizure_lstm.keras           # Keras LSTM model
│   ├── seizure_lstm.tflite          # TFLite (Flex delegate, 61 KB)
│   ├── cortisol_estimator.joblib    # GradientBoostingRegressor
│   ├── cortisol_scaler.joblib       # StandardScaler for cortisol
│   ├── bio_age_rf.joblib            # RandomForest
│   ├── bio_age_xgb.joblib           # XGBoost
│   └── bio_age_scaler.joblib        # StandardScaler for bio age
│
├── pipeline/
│   ├── signal_processing/
│   │   ├── ppg_peaks.py             # PPG peak detection, RR extraction
│   │   ├── hrv_features.py          # RMSSD, LF/HF, SDNN
│   │   ├── spo2.py                  # Beer-Lambert SpO2 derivation
│   │   └── ecg_peaks.py             # Pan-Tompkins ECG R-peak detection
│   │
│   ├── synthetic/
│   │   └── baseline_generator.py   # Synthetic 30-day baseline data
│   │
│   ├── models/
│   │   ├── train_anomaly_forest.py
│   │   ├── train_seizure_lstm.py
│   │   ├── train_cortisol_estimator.py
│   │   └── train_bio_age_estimator.py
│   │
│   └── tests/
│       ├── test_signal_processing.py
│       ├── test_anomaly_forest.py
│       ├── test_seizure_lstm.py
│       ├── test_cortisol.py
│       └── test_bio_age.py
│
└── data/
    └── chb-mit/
        └── chb01-summary.txt        # CHB-MIT seizure annotations
                                     # (place chb01_*.edf here when available)
```

---

## Firebase integration

The pipeline outputs map directly to the Firebase Realtime Database schema at `/lifesphere/vital32/`:

| Firebase field | Source | Update cycle |
|---|---|---|
| `anomaly_score` | `anomaly_forest.tflite` | Every 30-second window |
| `seizure_prob` | `seizure_lstm.tflite` | Every 300-step window (~5 min at 1 Hz) |
| `cortisol_est` | `cortisol_estimator.joblib` | Every 15 minutes |
| `bio_age` | `bio_age_rf.joblib` + `bio_age_xgb.joblib` | Daily |
| `hrv_rmssd` | `hrv_features.py` | Every RR series update |
| `hrv_lf_hf` | `hrv_features.py` | Every 30-second window |
| `spo2` | `spo2.py` | Every 8-second window |

Anomaly threshold behavior: `anomaly_score > 0.7` → soft alert to SphereCore dashboard; `anomaly_score > 0.9` → emergency alert. Seizure threshold: `seizure_prob > 0.85` → HollowRover pre-seizure cushioning protocol.
