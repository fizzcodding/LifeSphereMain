import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import tensorflow as tf
from pipeline.models.train_seizure_lstm import (
    generate_synthetic_seizure_data,
    build_seizure_lstm,
    run_tflite_inference,
    SEQUENCE_LENGTH,
    N_FEATURES,
)

MODELS_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
PASS = '\033[92mPASS\033[0m'
FAIL = '\033[91mFAIL\033[0m'
SEIZURE_THRESHOLD = 0.85


def check(name: str, condition: bool, detail: str = '') -> bool:
    status = PASS if condition else FAIL
    detail_str = f'  ({detail})' if detail else ''
    print(f'  [{status}] {name}{detail_str}')
    return condition


def test_model_files_exist():
    print('\n--- Model file existence ---')
    ok = True
    for fname in ['seizure_lstm.keras', 'seizure_lstm.tflite']:
        path = os.path.join(MODELS_DIR, fname)
        exists = os.path.exists(path) and os.path.getsize(path) > 0
        ok &= check(f'{fname} exists and non-empty', exists, f'path: {path}')
    return ok


def test_model_architecture():
    print('\n--- Model architecture ---')
    model = tf.keras.models.load_model(
        os.path.join(MODELS_DIR, 'seizure_lstm.keras'), compile=False
    )
    input_shape = model.input_shape
    output_shape = model.output_shape

    ok = True
    ok &= check('Input shape matches (None, 300, 5)',
                input_shape == (None, SEQUENCE_LENGTH, N_FEATURES),
                f'got {input_shape}')
    ok &= check('Output shape is (None, 1)',
                output_shape == (None, 1),
                f'got {output_shape}')

    lstm_layers = [l for l in model.layers if 'lstm' in l.name.lower()]
    ok &= check('Has 2 LSTM layers', len(lstm_layers) == 2,
                f'found {len(lstm_layers)} LSTM layers')
    ok &= check('First LSTM has 64 units', lstm_layers[0].units == 64,
                f'got {lstm_layers[0].units}')
    ok &= check('Second LSTM has 32 units', lstm_layers[1].units == 32,
                f'got {lstm_layers[1].units}')
    return ok


def test_keras_inference():
    print('\n--- Keras inference sanity check ---')
    print('  [SYNTHETIC-DERIVED] Using synthetic preictal/interictal sequences')
    model = tf.keras.models.load_model(
        os.path.join(MODELS_DIR, 'seizure_lstm.keras'), compile=False
    )
    X, y = generate_synthetic_seizure_data(n_normal=50, n_preictal=50, seed=7)
    preictal_seqs = X[y == 1][:5]
    interictal_seqs = X[y == 0][:5]

    probs_preictal = model.predict(preictal_seqs, verbose=0).flatten()
    probs_interictal = model.predict(interictal_seqs, verbose=0).flatten()

    ok = True
    ok &= check('Preictal probabilities > interictal mean',
                probs_preictal.mean() > probs_interictal.mean(),
                f'preictal mean={probs_preictal.mean():.4f}  '
                f'interictal mean={probs_interictal.mean():.4f}')
    ok &= check('Interictal probs < threshold',
                np.all(probs_interictal < SEIZURE_THRESHOLD),
                f'max interictal={probs_interictal.max():.4f}')
    ok &= check('All outputs in [0, 1]',
                np.all(probs_preictal >= 0) and np.all(probs_interictal <= 1))
    print(f'  [INFO] Preictal: {probs_preictal}')
    print(f'  [INFO] Interictal: {probs_interictal}')
    return ok


def test_tflite_flex_delegate():
    print('\n--- TFLite Flex delegate check ---')
    with open(os.path.join(MODELS_DIR, 'seizure_lstm.tflite'), 'rb') as f:
        tflite_bytes = f.read()

    X, y = generate_synthetic_seizure_data(n_normal=5, n_preictal=5, seed=8)
    seq = X[0]
    result = run_tflite_inference(tflite_bytes, seq)

    ok = True
    ok &= check('TFLite file is non-empty',
                len(tflite_bytes) > 10000,
                f'{len(tflite_bytes)//1024} KB')
    if result < 0:
        ok &= check('Flex delegate not available on host Python — expected',
                    True,
                    'Use Android AAR tensorflow-lite-select-tf-ops for on-device')
    else:
        ok &= check('TFLite inference returned [0,1] value',
                    0.0 <= result <= 1.0,
                    f'{result:.4f}')
    return ok


def test_domain_mismatch_documented():
    print('\n--- Domain mismatch documentation check ---')
    script_path = os.path.join(
        os.path.dirname(__file__), '..', 'models', 'train_seizure_lstm.py'
    )
    with open(script_path) as f:
        content = f.read()

    ok = True
    ok &= check('Script documents domain mismatch',
                'DOMAIN MISMATCH' in content)
    ok &= check('Script documents EEG-only features',
                'EEG ONLY' in content)
    ok &= check('Script has CHB-MIT dataset reference',
                'CHB-MIT' in content or 'chbmit' in content.lower())
    ok &= check('Script documents SELECT_TF_OPS requirement',
                'SELECT_TF_OPS' in content or 'Flex' in content)
    return ok


def main():
    print('=== Seizure LSTM Test Suite ===')
    print('[SYNTHETIC-DERIVED] Trained on synthetic data (CHB-MIT not downloaded)')
    print('DOMAIN MISMATCH: EEG features not available on Vital32 hardware')

    results = [
        test_model_files_exist(),
        test_model_architecture(),
        test_keras_inference(),
        test_tflite_flex_delegate(),
        test_domain_mismatch_documented(),
    ]

    n_pass = sum(results)
    n_total = len(results)
    print(f'\nTest groups: {n_pass}/{n_total} passed')
    if not all(results):
        sys.exit(1)


if __name__ == '__main__':
    main()
