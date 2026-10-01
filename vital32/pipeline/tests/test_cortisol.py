import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import joblib
from pipeline.models.train_cortisol_estimator import (
    predict_cortisol,
    _generate_synthetic_cortisol_data,
    FEATURE_COLUMNS,
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
    for fname in ['cortisol_estimator.joblib', 'cortisol_scaler.joblib']:
        path = os.path.join(MODELS_DIR, fname)
        ok &= check(f'{fname} exists', os.path.exists(path))
    return ok


def test_inference_range():
    print('\n--- Cortisol inference range ---')
    print('  [SYNTHETIC-DERIVED]')
    model = joblib.load(os.path.join(MODELS_DIR, 'cortisol_estimator.joblib'))
    scaler = joblib.load(os.path.join(MODELS_DIR, 'cortisol_scaler.joblib'))

    low_stress = np.array([55.0, 0.2, 36.1, 0.90], dtype=np.float32)
    high_stress = np.array([18.0, 1.2, 36.5, 0.55], dtype=np.float32)
    morning = np.array([30.0, 0.6, 35.9, 0.82], dtype=np.float32)

    est_low = predict_cortisol(model, scaler, low_stress)
    est_high = predict_cortisol(model, scaler, high_stress)
    est_morning = predict_cortisol(model, scaler, morning)

    ok = True
    ok &= check('Low-stress estimate in plausible range',
                1.0 <= est_low <= 20.0,
                f'{est_low:.1f} ng/dL')
    ok &= check('High-stress estimate > low-stress estimate',
                est_high > est_low,
                f'{est_high:.1f} > {est_low:.1f}')
    ok &= check('Morning cortisol > resting level',
                est_morning > est_low,
                f'{est_morning:.1f} > {est_low:.1f}')
    ok &= check('All estimates positive', est_low > 0 and est_high > 0 and est_morning > 0)
    print(f'  [INFO] low={est_low:.1f}  high={est_high:.1f}  morning={est_morning:.1f} ng/dL')
    return ok


def test_batch_prediction():
    print('\n--- Batch prediction on synthetic data ---')
    model = joblib.load(os.path.join(MODELS_DIR, 'cortisol_estimator.joblib'))
    scaler = joblib.load(os.path.join(MODELS_DIR, 'cortisol_scaler.joblib'))
    X, y = _generate_synthetic_cortisol_data(n_samples=200, seed=13)
    X_scaled = scaler.transform(X)
    preds = model.predict(X_scaled)

    ok = True
    ok &= check('All predictions positive', np.all(preds > 0),
                f'min={preds.min():.2f}')
    ok &= check('Prediction range physiologically bounded',
                preds.max() < 80.0,
                f'max={preds.max():.1f} ng/dL')
    ok &= check('Prediction std > 0 (model is not constant)',
                preds.std() > 0.5,
                f'std={preds.std():.2f}')
    return ok


def test_feature_columns():
    print('\n--- Feature column definition ---')
    ok = True
    ok &= check('4 feature columns defined', len(FEATURE_COLUMNS) == 4,
                str(FEATURE_COLUMNS))
    expected = ['rmssd_ms', 'gsr_uS', 'skin_temp_C', 'sleep_efficiency']
    ok &= check('Correct feature column names',
                FEATURE_COLUMNS == expected,
                f'got {FEATURE_COLUMNS}')
    return ok


def main():
    print('=== Cortisol Estimator Test Suite ===')
    print('[SYNTHETIC-DERIVED] All tests use synthetic proxy data')
    print('WARNING: No real cortisol ground truth exists for wearable inputs')

    results = [
        test_model_files_exist(),
        test_inference_range(),
        test_batch_prediction(),
        test_feature_columns(),
    ]

    n_pass = sum(results)
    n_total = len(results)
    print(f'\nTest groups: {n_pass}/{n_total} passed')
    if not all(results):
        sys.exit(1)


if __name__ == '__main__':
    main()
