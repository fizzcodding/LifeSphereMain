import argparse
import csv
import time
from datetime import datetime
from pathlib import Path

import serial

parser = argparse.ArgumentParser()
parser.add_argument("--port", required=True)
parser.add_argument("--baud", type=int, default=115200)
parser.add_argument("--output", default="../data")
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
session = root / args.output / datetime.now().strftime("%Y%m%d_%H%M%S")
session.mkdir(parents=True, exist_ok=True)

SCHEMAS = {
    "E": ["timestamp_ms", "ecg_adc", "leads_off"],
    "P": ["timestamp_ms", "red", "ir"],
    "S": [
        "timestamp_ms", "ax", "ay", "az",
        "gx", "gy", "gz",
        "air_temp_c", "humidity_pct", "pressure_hpa",
        "object_temp_c", "ambient_temp_c", "gas_resistance_ohm",
        "steps", "gsr_raw", "uv_raw", "ecg_leads_off",
    ],
    "T": ["timestamp_ms", "temp_c", "rate_c_per_hour", "cusum", "baseline_ready", "trend_alert", "label"],
    "MOTOR_FEATURE": ["timestamp_ms", "gyro_rms", "tremor_band_power", "tremor_band_ratio"],
}

CSV_NAMES = {
    "E": "ecg.csv",
    "P": "ppg.csv",
    "S": "sensors.csv",
    "T": "temperature.csv",
    "MOTOR_FEATURE": "motor.csv",
}

T_LABEL_INDEX = SCHEMAS["T"].index("label")

files = {}
writers = {}

try:
    for key, columns in SCHEMAS.items():
        f = open(session / CSV_NAMES[key], "w", newline="")
        w = csv.writer(f)
        w.writerow(columns)
        files[key] = f
        writers[key] = w

    with serial.Serial(args.port, args.baud, timeout=1) as ser:
        time.sleep(2)
        ser.reset_input_buffer()
        print(f"Logging to: {session}")
        print("Press Ctrl+C to stop.")

        while True:
            raw = ser.readline().decode("utf-8", errors="replace").strip()

            if not raw:
                continue

            parts = raw.split(",")
            prefix = parts[0]

            if prefix == "BOOT":
                print(f"BOOT: {raw}")
                continue

            if prefix not in SCHEMAS:
                continue

            expected = len(SCHEMAS[prefix]) + 1
            if len(parts) != expected:
                print(f"Skipped malformed {prefix} record: {raw}")
                continue

            data_parts = parts[1:]

            if prefix == "T":
                try:
                    numeric_parts = [float(v) for v in data_parts[:T_LABEL_INDEX]]
                except ValueError:
                    print(f"Skipped non-numeric T record: {raw}")
                    continue
                label_str = data_parts[T_LABEL_INDEX]
                row = numeric_parts + [label_str]
            else:
                try:
                    row = [float(v) for v in data_parts]
                except ValueError:
                    print(f"Skipped non-numeric {prefix} record: {raw}")
                    continue

            writers[prefix].writerow(row)
            files[prefix].flush()

except KeyboardInterrupt:
    print("\nLogging stopped.")

finally:
    for f in files.values():
        f.close()
