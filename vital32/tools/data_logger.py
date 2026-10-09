
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

schemas = {
    "ECG": ["timestamp_ms", "ecg_raw", "leads_off"],
    "SENSORS": [
        "timestamp_ms", "acceleration_x", "acceleration_y",
        "acceleration_z", "gyro_x", "gyro_y", "gyro_z",
        "air_temperature_c", "humidity_percent", "pressure_hpa",
        "red_raw", "ir_raw", "uv_raw", "potentiometer_raw"
    ],
    "TEMPERATURE": [
        "timestamp_ms", "ambient_temperature_c", "object_temperature_c"
    ]
}

files = {}
writers = {}

try:
    for name, columns in schemas.items():
        file = open(session / f"{name.lower()}.csv", "w", newline="")
        writer = csv.writer(file)
        writer.writerow(columns)
        files[name] = file
        writers[name] = writer

    with serial.Serial(args.port, args.baud, timeout=1) as ser:
        time.sleep(2)
        ser.reset_input_buffer()
        print(f"Logging to: {session}")
        print("Press Ctrl+C to stop.")

        while True:
            line = ser.readline().decode("utf-8", errors="replace").strip()

            if not line:
                continue

            parts = line.split(",")
            name = parts[0]

            if name not in schemas:
                continue

            if len(parts) != len(schemas[name]) + 1:
                print(f"Skipped malformed {name} record: {line}")
                continue

            try:
                values = [float(value) for value in parts[1:]]
            except ValueError:
                continue

            writers[name].writerow(values)
            files[name].flush()

except KeyboardInterrupt:
    print("\nLogging stopped.")

finally:
    for file in files.values():
        file.close()