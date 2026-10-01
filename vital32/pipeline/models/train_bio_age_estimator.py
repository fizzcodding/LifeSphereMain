"""
NO GROUND-TRUTH DATASET EXISTS — READ BEFORE USE
==================================================
Validated biological age estimation requires longitudinal cohort data
with mortality/morbidity outcomes, DNA methylation clocks (Horvath, Hannum),
or clinical composite scores (Levine PhenoAge) from blood panels.

No public wearable dataset provides simultaneous continuous sensor data
and validated biological age labels.

This script builds a RandomForest + XGBoost ensemble using a SYNTHETIC
PROXY TARGET derived from physiological relationships:

  bio_age_proxy = f(chronological_age + senescence_adjustments)

Adjustments are constructed from sensor features using literature-derived
directions:
  - Low HRV (RMSSD) accelerates biological age: Molina 2018, Frontiers
  - High resting heart rate: Cooney et al. 2010, European Heart Journal
  - Low SpO2 / impaired oxygen utilization: oxygen-aging hypothesis
  - High skin conductance (chronic sympathetic activation): allostatic load
  - Elevated skin temperature: systemic inflammation proxy
  - Low physical activity (accel_mag near 9.81 only): sedentary aging
  - Elevated BME688 gas resistance reduction: VOC accumulation

The ensemble outputs a biological age estimate in years. Positive deviation
from chronological age means accelerated aging; negative means slower aging.

REAL DEPLOYMENT REQUIRES:
  - Epigenetic clock data (DNA methylation) or validated composite scores
  - Longitudinal health outcomes (mortality, hospitalization)
  - Minimum hundreds of users tracked over months to years
  - Medical validation before clinical use

All metrics are [SYNTHETIC-DERIVED].
"""

import os
import sys
import numpy as np
import joblib
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.preprocessing import StandardScaler
import xgboost as xgb

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

FEATURE_COLUMNS = [
    'heart_rate',
    'spo2',
    'skin_temp_C',
    'hrv_rmssd',
    'hrv_lf_hf',
    'accel_mag',
    'gsr_uS',
    'ambient_temp',
    'humidity',
    'pressure',
    'gas_resistance',
]
N_FEATURES = len(FEATURE_COLUMNS)

CHRONOLOGICAL_AGE_MIN = 55
CHRONOLOGICAL_AGE_MAX = 90


def _generate_synthetic_bio_age_data(
    n_samples: int = 8000,
    seed: int = 42,
) -> tuple:
    """
    Generate synthetic biological age proxy data.
    Each sample is a 24-hour rolling window aggregate.
    """
    rng = np.random.default_rng(seed)

    chron_age = rng.uniform(CHRONOLOGICAL_AGE_MIN, CHRONOLOGICAL_AGE_MAX, n_samples)
    age_factor = (chron_age - 55.0) / 35.0

    heart_rate = np.clip(
        65.0 + 10.0 * age_factor + rng.normal(0, 5.0, n_samples),
        45.0, 110.0,
    )
    spo2 = np.clip(
        98.5 - 1.5 * age_factor + rng.normal(0, 0.4, n_samples),
        88.0, 100.0,
    )
    skin_temp_C = np.clip(
        36.5 - 0.1 * age_factor + rng.normal(0, 0.2, n_samples),
        34.5, 38.0,
    )
    hrv_rmssd = np.clip(
        50.0 - 15.0 * age_factor + rng.normal(0, 8.0, n_samples),
        5.0, 100.0,
    )
    hrv_lf_hf = np.clip(
        1.2 + 0.5 * age_factor + rng.exponential(0.3, n_samples),
        0.1, 6.0,
    )
    accel_mag = np.clip(
        10.5 - 0.5 * age_factor + rng.exponential(0.5, n_samples),
        9.0, 20.0,
    )
    gsr_uS = np.clip(
        0.5 + 0.3 * age_factor + rng.exponential(0.1, n_samples),
        0.05, 3.0,
    )
    ambient_temp = 24.0 + rng.normal(0, 1.5, n_samples)
    humidity = np.clip(55.0 + rng.normal(0, 5.0, n_samples), 20.0, 90.0)
    pressure = 1013.0 + rng.normal(0, 2.0, n_samples)
    gas_resistance = np.clip(
        80000.0 - 15000.0 * age_factor + rng.normal(0, 8000.0, n_samples),
        10000.0, 200000.0,
    )

    bio_age = (
        chron_age
        + 5.0 * (heart_rate - 70.0) / 30.0
        - 4.0 * (hrv_rmssd - 30.0) / 40.0
        + 3.0 * (gsr_uS - 0.4) / 0.5
        - 3.0 * (spo2 - 96.0) / 4.0
        - 2.0 * (accel_mag - 10.0) / 3.0
        + 1.5 * (hrv_lf_hf - 1.5) / 1.5
        + rng.normal(0, 2.5, n_samples)
    )
    bio_age = np.clip(bio_age, 40.0, 110.0)

    X = np.column_stack([
        heart_rate, spo2, skin_temp_C, hrv_rmssd, hrv_lf_hf,
        accel_mag, gsr_uS, ambient_temp, humidity, pressure, gas_resistance,
    ]).astype(np.float32)
    y = bio_age.astype(np.float32)
    return X, y, chron_age


def train_bio_age_ensemble(
    X_train: np.ndarray,
    y_train: np.ndarray,
) -> tuple:
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X_train)

    rf = RandomForestRegressor(
        n_estimators=200,
        max_depth=8,
        min_samples_leaf=5,
        n_jobs=-1,
        random_state=42,
    )
    rf.fit(X_scaled, y_train)

    xgb_model = xgb.XGBRegressor(
        n_estimators=200,
        max_depth=5,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        verbosity=0,
    )
    xgb_model.fit(X_scaled, y_train)

    return rf, xgb_model, scaler


def predict_bio_age(
    rf: RandomForestRegressor,
    xgb_model: xgb.XGBRegressor,
    scaler: StandardScaler,
    sample: np.ndarray,
    rf_weight: float = 0.5,
) -> dict:
    X_scaled = scaler.transform(sample.reshape(1, -1))
    rf_pred = float(rf.predict(X_scaled)[0])
    xgb_pred = float(xgb_model.predict(X_scaled)[0])
    ensemble_pred = rf_weight * rf_pred + (1.0 - rf_weight) * xgb_pred
    return {
        'bio_age_rf': rf_pred,
        'bio_age_xgb': xgb_pred,
        'bio_age_ensemble': ensemble_pred,
    }


def main():
    print('=== Biological Age Estimator Training ===')
    print('Data source: SYNTHETIC PROXY — see module docstring')
    print()
    print('WARNING: No real biological age ground-truth dataset exists for wearable inputs.')
    print('All metrics below are [SYNTHETIC-DERIVED].')
    print()

    X, y, chron_age = _generate_synthetic_bio_age_data(n_samples=8000, seed=42)
    print(f'Samples: {len(X)}  features: {X.shape[1]}')
    print(f'Chronological age range: [{chron_age.min():.0f}, {chron_age.max():.0f}] years')
    print(f'Bio age proxy range: [{y.min():.1f}, {y.max():.1f}] years')
    print(f'Mean bio age delta (bio-chron): {(y - chron_age).mean():.2f} ± {(y-chron_age).std():.2f} years')
    print()

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    rf, xgb_model, scaler = train_bio_age_ensemble(X_train, y_train)

    X_test_scaled = scaler.transform(X_test)
    rf_pred = rf.predict(X_test_scaled)
    xgb_pred = xgb_model.predict(X_test_scaled)
    ensemble_pred = 0.5 * rf_pred + 0.5 * xgb_pred

    for label, pred in [('RF', rf_pred), ('XGBoost', xgb_pred), ('Ensemble', ensemble_pred)]:
        mae = mean_absolute_error(y_test, pred)
        r2 = r2_score(y_test, pred)
        print(f'[SYNTHETIC-DERIVED] {label}: MAE={mae:.2f} years  R²={r2:.4f}')
    print()

    output_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
    os.makedirs(output_dir, exist_ok=True)
    joblib.dump(rf, os.path.join(output_dir, 'bio_age_rf.joblib'))
    joblib.dump(xgb_model, os.path.join(output_dir, 'bio_age_xgb.joblib'))
    joblib.dump(scaler, os.path.join(output_dir, 'bio_age_scaler.joblib'))
    print('Saved: models/bio_age_rf.joblib, bio_age_xgb.joblib, bio_age_scaler.joblib')

    print()
    print('--- Feature importances (RF) ---')
    for col, imp in sorted(zip(FEATURE_COLUMNS, rf.feature_importances_),
                           key=lambda x: -x[1]):
        print(f'  {col}: {imp:.4f}')

    print()
    print('--- Inference examples ---')
    profiles = [
        ('Age 65, healthy (HR=65, SpO2=98, RMSSD=55, low GSR)',
         [65.0, 98.0, 36.4, 55.0, 1.2, 10.8, 0.2, 24.0, 55.0, 1013.0, 85000.0]),
        ('Age 72, sedentary, high HR (HR=85, SpO2=96, RMSSD=25, high GSR)',
         [85.0, 96.0, 36.7, 25.0, 2.1, 9.9, 0.9, 24.0, 55.0, 1013.0, 60000.0]),
        ('Age 78, severe deconditioning (HR=92, SpO2=94, RMSSD=12)',
         [92.0, 94.0, 37.1, 12.0, 3.2, 9.85, 1.5, 24.0, 55.0, 1013.0, 45000.0]),
    ]

    for label, features in profiles:
        sample = np.array(features, dtype=np.float32)
        result = predict_bio_age(rf, xgb_model, scaler, sample)
        print(f'  {label}')
        print(f'    RF={result["bio_age_rf"]:.1f}  XGBoost={result["bio_age_xgb"]:.1f}  '
              f'Ensemble={result["bio_age_ensemble"]:.1f} years [SYNTHETIC-DERIVED]')

    print()
    print('DEPLOYMENT REQUIREMENT: Retrain with validated biological age labels.')
    print('PIPELINE POSITION: Daily update cycle (see Firebase schema: bio_age).')


if __name__ == '__main__':
    main()
