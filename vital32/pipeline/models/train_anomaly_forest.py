"""
SYNTHETIC DATA WARNING — trained entirely on synthetic 30-day baseline data.
All anomaly scores and threshold behaviors are calibrated to synthetic distributions.
This model must be retrained on real 30-day per-user baseline data before any
caregiving deployment. Performance numbers reported here are synthetic-derived only.
"""

import os
import sys
import numpy as np
import joblib
import tensorflow as tf
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from synthetic.baseline_generator import generate_user_baseline, generate_rolling_window_features


FEATURE_COLUMNS = [
    'heart_rate', 'spo2', 'skin_temp', 'hrv_rmssd', 'hrv_lf_hf',
    'accel_mag', 'gsr', 'ambient_temp', 'humidity', 'pressure', 'gas_resistance',
]
N_FEATURES = len(FEATURE_COLUMNS)


def train_isolation_forest(baseline_data: np.ndarray) -> tuple:
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(baseline_data)
    model = IsolationForest(
        n_estimators=100,
        contamination=0.05,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_scaled)
    raw_scores = model.decision_function(X_scaled)
    df_min = float(np.percentile(raw_scores, 1))
    df_max = float(np.percentile(raw_scores, 99))
    calibration = {'df_min': df_min, 'df_max': df_max}
    return model, scaler, calibration


def score_sample(
    model: IsolationForest,
    scaler: StandardScaler,
    calibration: dict,
    sample: np.ndarray,
) -> float:
    X_scaled = scaler.transform(sample.reshape(1, -1))
    df = model.decision_function(X_scaled)[0]
    df_min = calibration['df_min']
    df_max = calibration['df_max']
    score = (df_max - df) / (df_max - df_min + 1e-9)
    return float(np.clip(score, 0.0, 1.0))


def build_tflite_approximator(
    model: IsolationForest,
    scaler: StandardScaler,
    calibration: dict,
    training_data: np.ndarray,
    n_features: int = N_FEATURES,
) -> tuple:
    X_scaled = scaler.transform(training_data).astype(np.float32)
    df_scores = model.decision_function(X_scaled)
    df_min = calibration['df_min']
    df_max = calibration['df_max']
    y_targets = np.clip(
        (df_max - df_scores) / (df_max - df_min + 1e-9),
        0.0, 1.0,
    ).astype(np.float32)

    keras_model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(n_features,)),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid'),
    ])
    keras_model.compile(optimizer='adam', loss='mse', metrics=['mae'])
    keras_model.fit(
        X_scaled, y_targets,
        epochs=30,
        batch_size=512,
        validation_split=0.1,
        verbose=0,
    )
    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    return tflite_model, keras_model


def run_tflite_inference(
    tflite_model: bytes,
    sample: np.ndarray,
    scaler: StandardScaler,
) -> float:
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    X_scaled = scaler.transform(sample.reshape(1, -1)).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], X_scaled)
    interpreter.invoke()
    return float(interpreter.get_tensor(output_details[0]['index'])[0][0])


def main():
    print('=== Isolation Forest Training ===')
    print('Data source: SYNTHETIC — 30-day per-user baseline simulation')
    print()
    baseline = generate_user_baseline(seed=42, n_days=30)
    training_data = generate_rolling_window_features(baseline, window_seconds=30)
    print(f'Training samples: {len(training_data)}  features: {training_data.shape[1]}')

    forest_model, scaler, calibration = train_isolation_forest(training_data)
    print(f'IsolationForest fitted.')
    print(f'Score calibration: df_min={calibration["df_min"]:.5f}  df_max={calibration["df_max"]:.5f}')

    output_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
    os.makedirs(output_dir, exist_ok=True)
    joblib.dump(forest_model, os.path.join(output_dir, 'anomaly_forest.joblib'))
    joblib.dump(scaler, os.path.join(output_dir, 'anomaly_scaler.joblib'))
    joblib.dump(calibration, os.path.join(output_dir, 'anomaly_calibration.joblib'))
    print(f'Sklearn model saved.')
    print()

    print('Training TFLite approximator...')
    tflite_bytes, keras_model = build_tflite_approximator(
        forest_model, scaler, calibration, training_data
    )
    tflite_path = os.path.join(output_dir, 'anomaly_forest.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_bytes)
    print(f'TFLite model saved: models/anomaly_forest.tflite  ({len(tflite_bytes)//1024} KB)')
    print()

    print('--- Score Distribution on Training Data (synthetic-derived) ---')
    scores_sklearn = []
    scores_tflite = []
    for i in range(0, min(500, len(training_data))):
        scores_sklearn.append(score_sample(forest_model, scaler, calibration, training_data[i]))
        scores_tflite.append(run_tflite_inference(tflite_bytes, training_data[i], scaler))
    scores_sklearn = np.array(scores_sklearn)
    scores_tflite = np.array(scores_tflite)

    for label, scores in [('sklearn', scores_sklearn), ('TFLite', scores_tflite)]:
        print(f'  [{label}] mean={scores.mean():.4f}  std={scores.std():.4f}  '
              f'range=[{scores.min():.4f}, {scores.max():.4f}]')
        n_soft = np.sum(scores > 0.7)
        n_emerg = np.sum(scores > 0.9)
        print(f'         soft alerts(>0.7): {n_soft}/{len(scores)} '
              f'({100*n_soft/len(scores):.1f}%)  '
              f'emergency(>0.9): {n_emerg}/{len(scores)} '
              f'({100*n_emerg/len(scores):.1f}%)')
    print()

    print('--- Injected anomaly tests ---')
    normal_sample = training_data[100].copy()

    crisis_sample = training_data[100].copy()
    crisis_sample[0] = 145.0
    crisis_sample[3] = 1.5
    crisis_sample[1] = 87.0

    gradual_sample = training_data[100].copy()
    gradual_sample[0] = 95.0
    gradual_sample[3] = 18.0
    gradual_sample[4] = 5.5

    for label, sample in [
        ('Normal baseline', normal_sample),
        ('Crisis (HR=145, SpO2=87, RMSSD=1.5)', crisis_sample),
        ('Elevated (HR=95, RMSSD=18, LF/HF=5.5)', gradual_sample),
    ]:
        sk = score_sample(forest_model, scaler, calibration, sample)
        tfl = run_tflite_inference(tflite_bytes, sample, scaler)
        print(f'  {label}')
        print(f'    sklearn={sk:.4f}  TFLite={tfl:.4f}')
    print()
    print('NOTE: All numbers above are SYNTHETIC-DERIVED. Do not treat as real performance.')
    print('      Retrain on 30-day real user data before caregiving deployment.')


if __name__ == '__main__':
    main()
