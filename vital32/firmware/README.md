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
- The Python pipeline is already validated against CHB-MIT data.

The paper's "on-device" target is a design goal for a later revision where the
RDK X5 (10 TOPS NPU) takes over inference. The ESP32 is the sensor bridge.

## Pin Map (ADC1 Only - WiFi Compatible)

| Pin   | GPIO | ADC Channel | Function            | Notes                        |
|-------|------|-------------|---------------------|------------------------------|
| ECG   | 32   | ADC1_CH4    | AD8232 output       | analogRead, 250 Hz           |
| LO-   | 33   | ADC1_CH5    | AD8232 leads-off    | digitalRead only, not ADC    |
| LO+   | 25   | DAC1        | AD8232 leads-off    | digitalRead only, not ADC    |
| UV    | 36   | ADC1_CH0    | UV sensor ADC       | analogRead, 16x oversampled  |
| POT   | 34   | ADC1_CH6    | Potentiometer page  | analogRead, page select      |
| GSR   | 35   | ADC1_CH7    | GSR electrode       | analogRead, 16x oversampled  |

All analogRead() calls use ADC1 pins (32, 36, 34, 35). GPIO25 and GPIO33 are
used only as digitalRead() for lead-off detection and are never passed to ADC.
WiFi and ADC1 coexist correctly on this board.

GSR note: the README previously claimed SPI for GSR. The firmware uses
analogRead(GSR_PIN) on GPIO35. The sensor is a passive electrode pair measured
via ADC, not SPI. The gsr_verified flag stays false until resistor bench
testing confirms the ADC response is monotonic.

## Secrets Setup (required before flashing)

```
cp vital32/firmware/secrets.h.example vital32/firmware/vital32/secrets.h
```

Edit `vital32/firmware/vital32/secrets.h` and fill in:
- `FB_WIFI_SSID` - your WiFi network name
- `FB_WIFI_PASSWORD` - your WiFi password
- `FB_DATABASE_URL` - Firebase RTDB URL, no trailing slash
- `FB_DEVICE_EMAIL` - dedicated device Firebase account email
- `FB_DEVICE_PASSWORD` - that account's password
- `FB_WEB_API_KEY` - Firebase project web API key

The file is gitignored. Never commit it.

Create the device Firebase account at console.firebase.google.com under
Authentication, enable Email/Password provider, add a user like
vital32-device@yourproject.firebaseapp.com with a strong password.
Set the database rules from vital32/database.rules.json.

## TLS Note

The firmware calls `client.setInsecure()` for HTTPS. This is gated behind
`VITAL32_TLS_INSECURE` which is set to 1 in firebase_writter.h until a pinned
CA is embedded. To enable real certificate verification: obtain the ISRG Root X1
PEM for googleapis.com and firebaseio.com, embed it in firebase_writter.h, and
set `VITAL32_TLS_INSECURE 0`. This was not done because embedding CA certs
without live verification against the actual endpoint is not safe to do
confidently.

## Library Dependencies

All confirmed present in ~/Arduino/libraries:
- Adafruit_SSD1306 2.5.15
- Adafruit_MPU6050 2.2.9
- Adafruit_MLX90614_Library 2.1.6
- SparkFun MAX3010x Pulse and Proximity Sensor Library 1.1.2
- Adafruit_BME680_Library 2.0.6
- ArduinoJson 7.4.2
- Adafruit_GFX_Library, Adafruit_BusIO, Adafruit_Unified_Sensor (deps)

Board core: esp32:esp32 2.0.0

## Compile and Flash

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 vital32/firmware/vital32
arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32 vital32/firmware/vital32
```

Last verified compile output (exit 0):
- Sketch uses 998561 bytes (76%) of program storage space. Maximum is 1310720 bytes.
- Global variables use 43760 bytes (13%) of dynamic memory.
- One benign warning: I2C_BUFFER_LENGTH redefined between Wire.h and MAX30105.h.

## Serial Output Format

High-rate streams (E and P) are off by default. Set `LOG_RAW_STREAM 1` in
vital32.ino and recompile to enable them.

```
BOOT,sensor,OK|FAIL
E,timestamp_ms,ecg_adc,leads_off          (250 Hz, only when LOG_RAW_STREAM=1)
P,timestamp_ms,red,ir                     (per PPG sample, only when LOG_RAW_STREAM=1)
S,timestamp_ms,ax,ay,az,gx,gy,gz,airTemp,humidity,pressure,objectTemp,ambientTemp,gasResistance,steps,gsrRaw,uvRaw,ecgLeadsOff  (1 Hz)
T,timestamp_ms,tempC,rateC_per_hour,cusum,baseline_ready,trend_alert,label  (1 Hz)
MOTOR_FEATURE,timestamp_ms,gyro_rms,tremor_band_power,tremor_band_ratio
STACK,firebase,highWaterMark              (only when VITAL32_DEBUG_STACK=1)
```

## Firebase Schema Written by Firmware

```
users/{uid}/vital32/
  hr/currently          int BPM (only when hr_valid=true)
  hr/valid              bool
  temp/currently        float C (one decimal)
  steps/currently       int
  raw/accel_x,y,z       float g
  raw/gyro_x,y,z        float rad/s
  raw/pressure_hpa      float
  raw/humidity_pct      float
  raw/gas_resistance_ohm float
  raw/altitude_m        float
  raw/uv_adc_raw        float
  gsr/currently         float ADC
  gsr/verified          false (always, until bench confirmed)
  status/fall_detected  bool
  status/ecg_leads_on   bool
  status/ts_ms          device uptime ms
  status/hr_valid       bool
  status/spo2_valid     false (always, calibration required)
  status/spo2_note      string
  status/server_ts      {".sv":"timestamp"} -> Firebase server Unix ms
  status/temp_trend_*   float/bool/string
  events/fall/          ts_ms, accel_peak_g, confirmed
```

spo2 is never written to hr/currently or spo2/currently while uncalibrated.
hr is only written when a valid reading exists (5-beat sliding window, 30-200 BPM).

## Bench-Test Checklist

Run in order after flashing. Do not skip steps.

### 1. Boot / OLED Self-Test
Power on. OLED shows "Vital32 booting" then individual BOOT lines on serial.
Expected: BOOT,MPU6050,OK / BOOT,BME680_688,OK / BOOT,MLX90614,OK /
BOOT,MAX30102,OK / BOOT,SSD1306,OK / BOOT,WIFI,CONNECTING.
WiFi connects asynchronously - the main loop starts immediately even if
WiFi is not up yet. No 10-second block.

### 2. Serial Monitor (115200 baud)
Open monitor. Should see S and T lines at ~1 Hz within a few seconds.
MOTOR_FEATURE lines appear every ~2.5 seconds once gyro window fills.

### 3. Accelerometer / Step Counter
Shake the unit in a walking motion 10 times.
OLED step count increments. Expect 8-12 steps counted.

### 4. Fall Detection
Hold still, drop 30 cm onto padded surface, catch sharply, place flat for 4s.
OLED shows "CHECK USER" briefly. Firebase events/fall/confirmed becomes true.

### 5. MAX30102 Heart Rate
Finger on sensor, wait 15s.
S line shows hr_valid=true. OLED shows BPM (50-100 expected at rest).
SpO2 is NOT written to Firebase. status/spo2_valid=false is expected.

### 6. MLX90614 Skin Temperature
Sensor against wrist dorsum.
T line temp_c reads 31-35.5 C (wrist skin range).
A reading of 36-37 is plausible over a superficial vein.
A reading of 0 or >45 means MLX init failed.

### 7. BME688 Environmental
Firebase raw/pressure_hpa reads local barometric pressure (990-1020 hPa at sea level).
raw/gas_resistance_ohm > 10000 after 5s warmup.

### 8. AD8232 ECG Lead Detection
status/ecg_leads_on=true when both leads attached.
Disconnect one lead: becomes false within one loop tick.

### 9. GSR (unverified protocol)
Bridge GSR jack with 470k resistor, note gsr/currently ADC value.
Replace with 100k: value should change. Replace with 1M: change opposite direction.
gsr/verified stays false until this test passes.

### 10. Firebase Schema Validation
Open Firebase console, confirm at users/{uid}/vital32:
- hr/valid (bool)
- hr/currently (int, only present when valid)
- status/spo2_valid = false
- status/server_ts (large Unix ms timestamp, not device uptime)
- status/ts_ms (device uptime ms, smaller number)
- status/hr_valid (bool)
- steps/currently (int)
- raw/pressure_hpa (float)

Run Python client check:
```bash
cd sphereai && venv/bin/python -c "
from core.spherecore_client import SphereCoreClient
import os
from dotenv import load_dotenv
load_dotenv('.env')
c = SphereCoreClient()
c.authenticate()
v = c.get_vitals()
print(v)
"
```
If server_ts is fresh, returns VitalSigns object. If stale or WiFi just came up,
returns None (expected, retry after 30s).

### 11. WiFi Drop / Reconnect
Pull WiFi mid-session. Main loop continues, OLED shows "offline".
Restore WiFi. Within 30s Firebase writes resume automatically.
No crash, no reboot required.
