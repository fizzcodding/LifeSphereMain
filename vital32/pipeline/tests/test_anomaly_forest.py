import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import joblib
from pipeline.models.train_anomaly_forest import (
    score_sample, run_tflite_inference,
    train_isolation_forest, build_tflite_approximator,
)
from pipeline.synthetic.baseline_generator import (
    generate_user_baseline, generate_rolling_window_features,
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
    for fname in ['anomaly_forest.joblib', 'anomaly_scaler.joblib',
                  'anomaly_calibration.joblib', 'anomaly_forest.tflite']:
        path = os.path.join(MODELS_DIR, fname)
        ok &= check(f'{fname} exists', os.path.exists(path),
                    f'path: {path}')
    return ok


def test_load_and_inference():
    print('\n--- Load saved model and score samples ---')
    forest = joblib.load(os.path.join(MODELS_DIR, 'anomaly_forest.joblib'))
    scaler = joblib.load(os.path.join(MODELS_DIR, 'anomaly_scaler.joblib'))
    calibration = joblib.load(os.path.join(MODELS_DIR, 'anomaly_calibration.joblib'))

    baseline = generate_user_baseline(seed=99, n_days=5)
    data = generate_rolling_window_features(baseline, window_seconds=30)
    normal_sample = data[0]

    crisis_sample = data[0].copy()
    crisis_sample[0] = 145.0
    crisis_sample[3] = 1.5
    crisis_sample[1] = 87.0

    score_normal = score_sample(forest, scaler, calibration, normal_sample)
    score_crisis = score_sample(forest, scaler, calibration, crisis_sample)

    ok = True
    ok &= check('Normal sample score in [0, 1]',
                0.0 <= score_normal <= 1.0,
                f'{score_normal:.4f}')
    ok &= check('Crisis sample score in [0, 1]',
                0.0 <= score_crisis <= 1.0,
                f'{score_crisis:.4f}')
    ok &= check('Crisis score > normal score',
                score_crisis > score_normal,
                f'crisis={score_crisis:.4f} > normal={score_normal:.4f}')
    ok &= check('Crisis score above soft alert threshold',
                score_crisis >= 0.7,
                f'{score_crisis:.4f} >= 0.7')

    print(f'  [INFO] Normal score: {score_normal:.4f}  Crisis score: {score_crisis:.4f}')
    return ok


def test_score_distribution():
    print('\n--- Score distribution on synthetic baseline ---')
    forest = joblib.load(os.path.join(MODELS_DIR, 'anomaly_forest.joblib'))
    scaler = joblib.load(os.path.join(MODELS_DIR, 'anomaly_scaler.joblib'))
    calibration = joblib.load(os.path.join(MODELS_DIR, 'anomaly_calibration.joblib'))

    baseline = generate_user_baseline(seed=42, n_days=30)
    data = generate_rolling_window_features(baseline, window_seconds=30)
    rng = np.random.default_rng(7)
    idx = rng.integers(0, len(data), 1000)
    scores = np.array([score_sample(forest, scaler, calibration, data[i]) for i in idx])

    ok = True
    ok &= check('Median score < 0.6 (most normal baseline is not anomalous)',
                np.median(scores) < 0.6,
                f'median={np.median(scores):.4f}')
    ok &= check('Scores have variance (not all constant)',
                scores.std() > 0.05,
                f'std={scores.std():.4f}')
    ok &= check('Max score reaches high range',
                scores.max() > 0.5,
                f'max={scores.max():.4f}')
    ok &= check('Min score near 0',
                scores.min() < 0.2,
                f'min={scores.min():.4f}')
    ok &= check('Alert rate 0-15% (contamination=0.05)',
                0.0 < np.mean(scores > 0.7) < 0.15,
                f'{100*np.mean(scores>0.7):.1f}% above 0.7')
    print(f'  [INFO] mean={scores.mean():.4f}  std={scores.std():.4f}  '
          f'p5={np.percentile(scores,5):.4f}  p95={np.percentile(scores,95):.4f}')
    return ok


def test_tflite_inference():
    print('\n--- TFLite model inference ---')
    scaler = joblib.load(os.path.join(MODELS_DIR, 'anomaly_scaler.joblib'))
    with open(os.path.join(MODELS_DIR, 'anomaly_forest.tflite'), 'rb') as f:
        tflite_bytes = f.read()

    baseline = generate_user_baseline(seed=42, n_days=5)
    data = generate_rolling_window_features(baseline, window_seconds=30)
    normal_sample = data[500]

    score = run_tflite_inference(tflite_bytes, normal_sample, scaler)

    ok = True
    ok &= check('TFLite score is a float', isinstance(score, float))
    ok &= check('TFLite score in [0, 1]',
                0.0 <= score <= 1.0,
                f'{score:.4f}')
    print(f'  [INFO] TFLite normal score: {score:.4f}')
    return ok


def main():
    print('=== Anomaly Forest Test Suite ===')
    print('[SYNTHETIC-DERIVED] All tests use synthetic baseline data')

    results = [
        test_model_files_exist(),
        test_load_and_inference(),
        test_score_distribution(),
        test_tflite_inference(),
    ]

    n_pass = sum(results)
    n_total = len(results)
    print(f'\nTest groups: {n_pass}/{n_total} passed')
    if not all(results):
        sys.exit(1)


if __name__ == '__main__':
    main()
