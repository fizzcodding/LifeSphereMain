# Vital32 Firmware

## Architecture: Cloud-Side HRV / Anomaly Scoring

The ESP32 WROOM-32 reads all sensors on a millis()-based schedule, packages raw
values into JSON, and pushes to Firebase Realtime Database every 5 seconds. All
signal processing (RR-peak detection, RMSSD, Isolation Forest scoring, LSTM
pre-seizure inference) runs in the Python pipeline on the server side.

Why not on-device:
- WiFi stack + FreeRTOS consume ~100 KB of the 300 KB usable SRAM before
  application code runs.
- Isolation Forest (100 trees, scikit-learn) has no TFLite representation.
  Only Keras/TF neural networks convert to TFLite. Porting the forest to C++
  manually is a separate project.
- The Python pipeline is already validated against CHB-MIT data. Duplicating it
  in C++ without a bench validation path adds risk with no gain at this stage.

The paper's "on-device" target is a design goal for a later revision where the
RDK X5 (10 TOPS NPU) takes over inference. The ESP32 is the sensor bridge.

## Unverified Flags

**GSR (CJMCU-6701)** — The SPI read in `vital32.ino::readGsr()` is a generic
12-bit SPI read. The CJMCU-6701 chip markings have not been confirmed against a
real datasheet. The firmware marks every GSR reading with `gsr_verified: false`
in Firebase. Before trusting any GSR value:
1. Identify the actual IC on the board (scrape markings, check underside).
2. Run the resistor bench test: bridge the jack with 100 kΩ, 470 kΩ, 1 MΩ in
   sequence and confirm the raw ADC value changes monotonically.
3. Once confirmed, change `gsr_verified` to `true` in `readGsr()`.

**Skin temperature threshold in BiologyAgent** — `biology_agent.py` flags
`temperature_abnormal` outside 36.1–37.5°C. That is core body temperature range,
not wrist skin range. Wrist skin typically reads 32–35°C on MLX90614. The firmware
sends the raw MLX reading unchanged. The BiologyAgent threshold needs correcting
to approximately 31.0–35.5°C for wrist-worn measurements. The firmware does not
apply any temperature flag logic; that is the Python side's responsibility.

## Required Configuration Before Flashing

Edit `firebase_writter.h` and set the four constants at the top:
- `FB_WIFI_SSID` — your network SSID
- `FB_WIFI_PASSWORD` — your network password
- `FB_DATABASE_URL` — your Firebase Realtime Database URL
- `FB_AUTH_TOKEN` — a Firebase Database Secret or a short-lived auth token
- `FB_USER_UID` — the Firebase Auth UID of the user account

## Library Dependencies

All confirmed present in ~/Arduino/libraries:
- Adafruit_SSD1306 2.5.15
- Adafruit_MPU6050 2.2.9
- Adafruit_MLX90614_Library 2.1.6
- SparkFun MAX3010x Pulse and Proximity Sensor Library 1.1.2
- Adafruit_BME680_Library 2.0.6
- ArduinoJson 7.4.2
- Adafruit_GFX_Library, Adafruit_BusIO, Adafruit_Unified_Sensor (pulled as deps)

Board core: esp32:esp32 2.0.0

Compile command (verified clean, exit 0):
```
arduino-cli compile --fqbn esp32:esp32:esp32 vital32/
```
Flash command:
```
arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32 vital32/
```

## Bench-Test Checklist

Run these in order after flashing. Do not skip any step.

### 1. Boot / OLED Self-Test
- Power on the board. OLED should display "Vital32 Ready" with individual
  OK/FAIL lines for WiFi, MPU, MAX, MLX, BME.
- Expected: all five lines show OK.
- If MPU/MAX/MLX/BME shows FAIL: re-check I2C wiring on the failing bus.
  Bus A (SDA 21, SCL 22): SSD1306, MPU6050, BME688.
  Bus B (SDA 19, SCL 18): MAX30102, MLX90614.
- After 2 seconds the main loop starts and OLED switches to live vitals.

### 2. Serial Monitor Baseline (115200 baud)
- Open serial monitor. You should see no error output and the loop should
  run silently.
- If you see repeated WiFi reconnect messages, check credentials in
  `firebase_writter.h`.

### 3. Accelerometer / Step Counter
- Shake the wrist unit 10 times in a walking motion.
- OLED step count should increment. Confirm it counts ~8–12 steps (not 0,
  not 50+). If zero: MPU6050 init failed or `STEP_ACCEL_THRESHOLD_G` is too high.

### 4. Fall Detection
- Hold the unit still, then drop it 30 cm onto a padded surface (freefall
  stage), catch it with a sharp stop (impact stage), then place it flat and
  don't move it for 4 seconds.
- OLED should briefly show "!! FALL !!" and Firebase
  `vital32/events/fall/confirmed` should become `true`.
- Reset: pick up the unit; fall state returns to IDLE automatically.
- If no fall detected: check that the drop provides actual freefall
  (< 0.4g for at least 1 sample) before the impact. A slow drop onto a
  cushion will not trigger it.

### 5. MAX30102 Heart Rate
- Place finger firmly on the MAX30102 sensor.
- Wait 15 seconds. OLED HR should settle to a plausible value (50–100 BPM).
- SpO2 ring gauge should show > 90%.
- If HR stays 0: check IR signal threshold (50000 counts). Very dark skin
  or poor contact can drop the IR signal below threshold; increase LED power
  with `max30102.setPulseAmplitudeRed(0x1F)` if needed.

### 6. MLX90614 Skin Temperature
- Hold the sensor flat against the back of the wrist.
- Expected reading: 32–35°C. A reading of 0 or > 45 means the MLX init
  failed or there is no I2C contact. A reading of 36–37°C is plausible if
  the sensor is pressed directly over a superficial vein.

### 7. BME688 Environmental
- OLED does not display BME values but they appear in Firebase raw/.
- Confirm `vital32/raw/pressure_hpa` reads approximately local barometric
  pressure (typically 990–1020 hPa at sea level).
- `vital32/raw/gas_resistance_ohm` should be > 10,000 Ω after a 5-second
  warmup reading. A value of 0 means performReading() failed.

### 8. AD8232 ECG Lead Detection
- OLED shows "ECG:OK" when both LO- (GPIO33) and LO+ (GPIO25) are LOW,
  meaning the leads are on.
- Disconnect one lead: OLED should immediately show "ECG:OFF".
- Reconnect: should return to "ECG:OK" within one loop tick.
- Firebase `vital32/status/ecg_leads_on` must match the OLED state in
  real time.

### 9. GSR (CJMCU-6701) — Protocol Unverified
- Bridge the GSR jack with a 470 kΩ resistor.
- Check `vital32/gsr/currently` in Firebase. Note the raw ADC value.
- Replace with 100 kΩ. The value should change. Replace with 1 MΩ — it
  should change in the opposite direction.
- If the value does not change at all across resistors, the SPI protocol
  is wrong. Do not mark GSR as verified until this passes.
- `vital32/gsr/verified` remains `false` until confirmed in firmware.

### 10. Firebase Schema Validation
- Open Firebase console → Realtime Database → users/{uid}/vital32.
- Confirm all of these paths exist and have non-zero values:
  - `hr/currently` (int, BPM)
  - `spo2/currently` (int, %)
  - `temp/currently` (float, °C, one decimal)
  - `steps/currently` (int)
  - `raw/accel_x`, `raw/accel_y`, `raw/accel_z`
  - `raw/pressure_hpa`
  - `raw/humidity_pct`
  - `gsr/currently` (raw ADC)
  - `gsr/verified` (should be `false`)
  - `status/ecg_leads_on` (bool)
  - `status/ts_ms` (incrementing timestamp)
- Run `python sphereai/core/spherecore_client.py` (or its test) and confirm
  `get_vitals()` returns a VitalSigns object with non-zero hr, spo2, temp.

### 11. WiFi Drop / Reconnect
- Power on, let Firebase writes stabilize.
- Pull WiFi (disable the router or change SSID temporarily).
- The main loop must continue running with no crash. OLED should show
  "NoWiFi" in the status row.
- Restore WiFi. Within 30 seconds (reconnect interval) Firebase writes
  should resume automatically.
