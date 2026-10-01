import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import joblib
from pipeline.models.train_bio_age_estimator import (
    predict_bio_age,
    _generate_synthetic_bio_age_data,
    FEATURE_COLUMNS,
    CHRONOLOGICAL_AGE_MIN,
    CHRONOLOGICAL_AGE_MAX,
)

MODELS_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
PASS = '\033[92mPASS\033[0m'
FAIL = '\033[91mFAIL\033[0m'


def check(name: str, condition: bool, detail: str = '') -> bool:
    status = PASS if condition else FAIL
    detail_str = f'  ({detail})' if detail else ''
    print(f'  [{status}] {name}{detail_str}')
    return condition


def test_model_files_exist():
    print('\n--- Model file existence ---')
    ok = True
    for fname in ['bio_age_rf.joblib', 'bio_age_xgb.joblib', 'bio_age_scaler.joblib']:
        path = os.path.join(MODELS_DIR, fname)
        ok &= check(f'{fname} exists', os.path.exists(path))
    return ok


def test_inference_examples():
    print('\n--- Bio age inference examples ---')
    print('  [SYNTHETIC-DERIVED]')
    rf = joblib.load(os.path.join(MODELS_DIR, 'bio_age_rf.joblib'))
    xgb_model = joblib.load(os.path.join(MODELS_DIR, 'bio_age_xgb.joblib'))
    scaler = joblib.load(os.path.join(MODELS_DIR, 'bio_age_scaler.joblib'))

    healthy_65 = np.array([65.0, 98.0, 36.4, 55.0, 1.2, 10.8, 0.2, 24.0, 55.0, 1013.0, 85000.0])
    deconditioned_72 = np.array([85.0, 96.0, 36.7, 25.0, 2.1, 9.9, 0.9, 24.0, 55.0, 1013.0, 60000.0])

    result_healthy = predict_bio_age(rf, xgb_model, scaler, healthy_65)
    result_decond = predict_bio_age(rf, xgb_model, scaler, deconditioned_72)

    ok = True
    ok &= check('Healthy 65yo bio age in plausible range',
                40 <= result_healthy['bio_age_ensemble'] <= 90,
                f'{result_healthy["bio_age_ensemble"]:.1f} years')
    ok &= check('Deconditioned 72yo bio age >= healthy 65yo',
                result_decond['bio_age_ensemble'] >= result_healthy['bio_age_ensemble'],
                f'{result_decond["bio_age_ensemble"]:.1f} >= {result_healthy["bio_age_ensemble"]:.1f}')
    ok &= check('RF and XGBoost outputs are close (within 15 years)',
                abs(result_healthy['bio_age_rf'] - result_healthy['bio_age_xgb']) < 15,
                f'RF={result_healthy["bio_age_rf"]:.1f}  XGB={result_healthy["bio_age_xgb"]:.1f}')
    print(f'  [INFO] Healthy 65yo: RF={result_healthy["bio_age_rf"]:.1f}  '
          f'XGB={result_healthy["bio_age_xgb"]:.1f}  '
          f'Ensemble={result_healthy["bio_age_ensemble"]:.1f}')
    print(f'  [INFO] Decond 72yo: Ensemble={result_decond["bio_age_ensemble"]:.1f}')
    return ok


def test_batch_predictions():
    print('\n--- Batch predictions on synthetic data ---')
    rf = joblib.load(os.path.join(MODELS_DIR, 'bio_age_rf.joblib'))
    xgb_model = joblib.load(os.path.join(MODELS_DIR, 'bio_age_xgb.joblib'))
    scaler = joblib.load(os.path.join(MODELS_DIR, 'bio_age_scaler.joblib'))
    X, y, chron = _generate_synthetic_bio_age_data(n_samples=300, seed=77)
    X_scaled = scaler.transform(X)
    rf_preds = rf.predict(X_scaled)
    xgb_preds = xgb_model.predict(X_scaled)
    ensemble = 0.5 * rf_preds + 0.5 * xgb_preds

    ok = True
    ok &= check('All predictions positive', np.all(ensemble > 0),
                f'min={ensemble.min():.1f}')
    ok &= check('Predictions in plausible human age range',
                np.all((ensemble > 30) & (ensemble < 120)),
                f'range=[{ensemble.min():.1f}, {ensemble.max():.1f}]')
    ok &= check('RF and XGBoost predictions correlated (r > 0.9)',
                float(np.corrcoef(rf_preds, xgb_preds)[0, 1]) > 0.9,
                f'r={np.corrcoef(rf_preds, xgb_preds)[0,1]:.3f}')
    print(f'  [INFO] Ensemble mean={ensemble.mean():.1f}  std={ensemble.std():.1f} years')
    return ok


def test_feature_columns():
    print('\n--- Feature column definition ---')
    ok = True
    ok &= check('11 feature columns defined', len(FEATURE_COLUMNS) == 11,
                f'got {len(FEATURE_COLUMNS)}')
    required_features = ['heart_rate', 'spo2', 'skin_temp_C', 'hrv_rmssd', 'hrv_lf_hf', 'gsr_uS']
    for feat in required_features:
        ok &= check(f'Feature {feat!r} present', feat in FEATURE_COLUMNS)
    return ok


def main():
    print('=== Biological Age Estimator Test Suite ===')
    print('[SYNTHETIC-DERIVED] All tests use synthetic proxy data')
    print('WARNING: No real biological age ground truth exists for wearable inputs')

    results = [
        test_model_files_exist(),
        test_inference_examples(),
        test_batch_predictions(),
        test_feature_columns(),
    ]

    n_pass = sum(results)
    n_total = len(results)
    print(f'\nTest groups: {n_pass}/{n_total} passed')
    if not all(results):
        sys.exit(1)


if __name__ == '__main__':
    main()
