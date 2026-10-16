#!/usr/bin/env python3
"""Log Vital32 machine-readable Serial output to a timestamped text file.
Install: python -m pip install pyserial
Usage: python tools/data_logger.py --port /dev/ttyUSB0 --baud 115200
"""
import argparse
from datetime import datetime
from pathlib import Path
import serial

p = argparse.ArgumentParser()
p.add_argument('--port', required=True, help='Serial device, e.g. /dev/ttyUSB0')
p.add_argument('--baud', type=int, default=115200)
p.add_argument('--out', default='data', help='Output directory')
a = p.parse_args()
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
path = out / f"vital32_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csvlog"
print(f"Logging {a.port} -> {path} (Ctrl+C to stop)")
try:
    with serial.Serial(a.port, a.baud, timeout=1) as ser, path.open('w', buffering=1) as f:
        ser.reset_input_buffer()
        while True:
            raw = ser.readline()
            if not raw:
                continue
            line = raw.decode('utf-8', errors='replace').strip()
            if line:
                print(line)
                f.write(line + '\n')
except KeyboardInterrupt:
    print('\nLogger stopped.')
