# Vital32 firmware refactor pack

This pack is based on the recovered `vital32(1).ino` source from the prior conversation. It is a prototype candidate, not a verified release. It has **not** been compiled against your installed Arduino core/libraries or tested on your exact wiring.

## Files

- `Vital32.ino` — main scheduler, sensor reads, OLED, serial records, and Firebase queue.
- `steps.h` — step counter (separate from HRV).
- `hrv.h` — beat-to-beat interval buffer; computes RMSSD and SDNN in milliseconds.
- `fall_detection.h` — freefall/impact/stillness threshold heuristic.
- `fever_trend.h` — rolling surface-temperature trend heuristic.
- `parkinson_motor_screen.h` — basic rolling gyroscope features for research data only; **not** a Parkinson's detector.
- `firebase_writter.h` — Firebase Realtime Database REST payload writer.
- `secrets.example.h` — configuration template. Copy to `secrets.h` and edit it locally.
- `tools/data_logger.py` — logs serial records to a timestamped file.
- `tools/plot_data.py` — plots ECG, PPG, motion, temperature, steps and HRV records.

## Setup

1. Copy `secrets.example.h` to `secrets.h` and fill in Wi-Fi, RTDB URL, token and UID.
2. Keep `secrets.h` out of Git. `.gitignore` excludes it.
3. Install Arduino libraries: Adafruit Unified Sensor, Adafruit MPU6050, Adafruit BME680, Adafruit MLX90614, Adafruit SSD1306, SparkFun MAX3010x Sensor Library. `heartRate.h` comes with the SparkFun MAX3010x library.
4. Open `Vital32.ino` in Arduino IDE with the sketch folder named `Vital32` (Arduino expects the `.ino` name to match the folder name), or rename the folder to `Vital32`.
5. Board target: classic ESP32 DevKit / ESP32-WROOM-32. These GPIOs are **not** a universal ESP32-S3 pin map.
6. Firebase transport is fail-closed by default: configure a trusted Firebase root CA in `firebase_writter.h`. `FB_ALLOW_INSECURE_TLS 1` permits `setInsecure()` only for temporary bench testing and exposes traffic to man-in-the-middle attacks; do not use it for real personal data.
7. `HUMAN_READABLE_SERIAL` is `0` so the logger receives machine-readable records. Set it to `1` for a human-readable status report instead (the plotter expects mode `0`).

## Pin map assumed by this source

- I2C A: SDA 21 / SCL 22 — MPU6050, BME680/688, OLED.
- I2C B: SDA 19 / SCL 18 — MLX90614, MAX30102.
- ECG analog: GPIO32; AD8232 lead-off: GPIO33 and GPIO25.
- UV analog: GPIO36; potentiometer: GPIO34; GSR analog: GPIO35.

The scanner previously found `0x3C`, `0x68`, `0x77` on bus A and `0x57`, `0x5A` on bus B. An I2C address acknowledgement proves communication at the bus level, not valid sensor readings or accurate measurements. In particular, the MAX30102 BPM/HRV depends on stable optical contact and usable beat detections.

## Serial logging and plots

```bash
python -m pip install pyserial pandas matplotlib
python tools/data_logger.py --port /dev/ttyUSB0 --baud 115200
# Stop with Ctrl+C, then:
python tools/plot_data.py data/vital32_YYYYMMDD_HHMMSS.csvlog
```

Use the correct serial device for your machine (e.g. `/dev/ttyACM0` on some boards). Close Arduino Serial Monitor before starting the logger.

## Algorithm caveats

- HRV RMSSD/SDNN are calculated from detected beat-to-beat intervals; motion artifacts and missed/double beats can make them wrong. They are not diagnostic.
- Step detection is a simple acceleration-magnitude heuristic and needs walking tests/tuning.
- Fall detection is a threshold heuristic and can miss falls or trigger falsely. It is not a safety-certified alert system.
- MLX90614 reads surface/object temperature, not core temperature. The trend module is experimental and not fever diagnosis.
- SpO2 is explicitly marked as not measured; this pack does not calculate SpO2.
- GSR and UV are logged as raw ADC readings, not calibrated physical units.
- The motor feature screen logs basic gyro statistics only; it does not detect Parkinson's disease.
- Firmware networking, sensor initialization, display behavior, timing, queue capacity, and all numerical thresholds still require bench validation.

## Why the main sketch has hundreds of lines

The main file coordinates two I2C buses, multiple sensor drivers, asynchronous BME reads, PPG beat handling, ECG sampling, motion processing, fall/step/HRV modules, OLED pages, serial output, and a FreeRTOS queue for network writes. That coordination is real functionality, not necessarily waste. Moving algorithms into headers keeps the `.ino` smaller without deleting behavior. Do not optimize purely for line count; prioritize clear module boundaries and verified behavior.
