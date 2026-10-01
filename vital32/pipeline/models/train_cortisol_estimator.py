"""
NO GROUND-TRUTH DATASET EXISTS — READ BEFORE USE
==================================================
Salivary/serum cortisol levels require biochemical assay (ELISA, mass
spectrometry) or continuous fiber-optic biosensors (research-only).
No public wearable dataset pairs simultaneous GSR/HRV/temperature
readings with biochemically validated cortisol concentrations.

This script builds a GradientBoostingRegressor using a SYNTHETIC PROXY
TARGET derived from physiological relationships documented in the
literature:

  cortisol_proxy = f(RMSSD, GSR, skin_temp, sleep_efficiency)

The proxy is constructed from:
  - Inverse relationship with RMSSD (cortisol suppresses vagal tone):
    Thayer et al. 2012, Psychoneuroendocrinology
  - Positive relationship with GSR (sympathetic co-activation):
    Nater et al. 2006, Psychophysiology
  - Diurnal temperature variation mirroring cortisol awakening response:
    Kudielka et al. 2009, Psychoneuroendocrinology
  - Inverse relationship with sleep efficiency:
    Vgontzas et al. 1997, JCEM (sleep deprivation elevates cortisol)

The proxy is NOT a validated cortisol measurement. It is a physiologically
motivated synthetic target that allows the pipeline to learn feature
relationships consistent with the endocrinology literature.

REAL DEPLOYMENT REQUIRES:
  - Minimum 50 users with simultaneous wearable + saliva samples (morning,
    noon, evening) over at least 7 days
  - A validated regression target (ng/dL from laboratory assay)
  - Per-user baseline normalization (cortisol varies 3x across individuals)

All metrics reported below are [SYNTHETIC-DERIVED] and must not be
treated as clinical validation or accuracy claims.
"""

import os
import sys
import numpy as np
import joblib
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

FEATURE_COLUMNS = ['rmssd_ms', 'gsr_uS', 'skin_temp_C', 'sleep_efficiency']
CORTISOL_UNIT = 'ng/dL (synthetic proxy)'


def _generate_synthetic_cortisol_data(
    n_samples: int = 5000,
    seed: int = 42,
) -> tuple:
    """
    Generate synthetic cortisol proxy data.

    Each sample represents a 15-minute aggregated window.
    Features reflect plausible physiological ranges for an elderly user.
    """
    rng = np.random.default_rng(seed)

    hour_of_day = rng.uniform(0, 24, n_samples)

    diurnal = 15.0 * np.exp(-0.5 * ((hour_of_day - 8.0) / 2.0) ** 2) + 5.0

    rmssd_ms = np.clip(
        50.0 - 0.3 * (diurnal - 10.0) + rng.normal(0, 10.0, n_samples),
        5.0, 120.0,
    )

    gsr_uS = np.clip(
        0.3 + 0.02 * (diurnal - 10.0) + rng.exponential(0.1, n_samples),
        0.01, 5.0,
    )

    skin_temp_C = np.clip(
        36.2 - 0.05 * (diurnal - 10.0) + rng.normal(0, 0.2, n_samples),
        34.0, 38.5,
    )

    sleep_eff = np.clip(
        0.85 - 0.02 * (diurnal > 20).astype(float) + rng.normal(0, 0.05, n_samples),
        0.3, 1.0,
    )

    cortisol_proxy = (
        diurnal
        - 0.12 * (rmssd_ms - 40.0)
        + 3.5 * (gsr_uS - 0.3)
        - 1.5 * (skin_temp_C - 36.2)
        - 5.0 * (sleep_eff - 0.75)
        + rng.normal(0, 1.5, n_samples)
    )
    cortisol_proxy = np.clip(cortisol_proxy, 1.0, 40.0)

    X = np.column_stack([rmssd_ms, gsr_uS, skin_temp_C, sleep_eff]).astype(np.float32)
    y = cortisol_proxy.astype(np.float32)
    return X, y


def train_cortisol_estimator(
    X_train: np.ndarray,
    y_train: np.ndarray,
) -> tuple:
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X_train)
    model = GradientBoostingRegressor(
        n_estimators=200,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.8,
        min_samples_leaf=10,
        random_state=42,
    )
    model.fit(X_scaled, y_train)
    return model, scaler


def predict_cortisol(
    model: GradientBoostingRegressor,
    scaler: StandardScaler,
    sample: np.ndarray,
) -> float:
    X_scaled = scaler.transform(sample.reshape(1, -1))
    return float(model.predict(X_scaled)[0])


def main():
    print('=== Cortisol Estimator Training ===')
    print('Data source: SYNTHETIC PROXY — see module docstring')
    print()
    print('WARNING: No real cortisol ground-truth dataset exists for wearable inputs.')
    print('All metrics below are [SYNTHETIC-DERIVED].')
    print()

    X, y = _generate_synthetic_cortisol_data(n_samples=5000, seed=42)
    print(f'Samples: {len(X)}  features: {X.shape[1]}  feature_columns: {FEATURE_COLUMNS}')
    print(f'Cortisol proxy range: [{y.min():.1f}, {y.max():.1f}] {CORTISOL_UNIT}')
    print(f'Cortisol proxy mean: {y.mean():.1f}  std: {y.std():.1f}')
    print()

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model, scaler = train_cortisol_estimator(X_train, y_train)

    y_pred = model.predict(scaler.transform(X_test))
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    print(f'[SYNTHETIC-DERIVED] Test MAE: {mae:.2f} ng/dL  R²: {r2:.4f}')
    print('NOTE: R² on synthetic data measures proxy self-consistency, not clinical accuracy.')
    print()

    output_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
    os.makedirs(output_dir, exist_ok=True)
    joblib.dump(model, os.path.join(output_dir, 'cortisol_estimator.joblib'))
    joblib.dump(scaler, os.path.join(output_dir, 'cortisol_scaler.joblib'))
    print('Saved: models/cortisol_estimator.joblib')

    print()
    print('--- Feature importances ---')
    for col, imp in sorted(zip(FEATURE_COLUMNS, model.feature_importances_),
                           key=lambda x: -x[1]):
        print(f'  {col}: {imp:.4f}')

    print()
    print('--- Inference examples (synthetic input) ---')
    low_stress = np.array([55.0, 0.2, 36.1, 0.90])
    high_stress = np.array([18.0, 1.2, 36.5, 0.55])
    morning_peak = np.array([30.0, 0.6, 35.9, 0.82])

    for label, sample in [
        ('Low stress (RMSSD=55, GSR=0.2, sleep_eff=0.90)', low_stress),
        ('High stress (RMSSD=18, GSR=1.2, sleep_eff=0.55)', high_stress),
        ('Morning peak (RMSSD=30, GSR=0.6, sleep_eff=0.82)', morning_peak),
    ]:
        est = predict_cortisol(model, scaler, sample)
        print(f'  {label}')
        print(f'    Estimate: {est:.1f} ng/dL [SYNTHETIC-DERIVED]')

    print()
    print('DEPLOYMENT REQUIREMENT: Retrain on real paired wearable+saliva dataset.')
    print('PIPELINE POSITION: 15-minute update cycle (see Firebase schema: cortisol_est).')


if __name__ == '__main__':
    main()
