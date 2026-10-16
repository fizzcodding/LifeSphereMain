#include <Arduino.h>
#include <Wire.h>
#include <math.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_BME680.h>
#include <Adafruit_MLX90614.h>
#include <Adafruit_SSD1306.h>
#include <MAX30105.h>
#include "heartRate.h"
#include "firebase_writter.h"
#include "fall_detection.h"
#include "steps.h"
#include "hrv.h"
#include "fever_trend.h"
#include "parkinson_motor_screen.h"

#define I2C_A_SDA 21
#define I2C_A_SCL 22
#define I2C_B_SDA 19
#define I2C_B_SCL 18
#define OLED_ADDR 0x3C

#define ECG_PIN 32
#define ECG_LO_MINUS_PIN 33
#define ECG_LO_PLUS_PIN 25
#define UV_PIN 36
#define POT_PIN 34
#define GSR_PIN 35

#define ECG_SAMPLE_PERIOD_MS 4
#define SENSOR_PERIOD_MS 1000
#define DISPLAY_PERIOD_MS 150
#define FIREBASE_PERIOD_MS 5000
#define PPG_STALE_MS 5000
#define FALL_LATCH_MS 30000
#define SERIAL_BAUD 115200

#define HUMAN_READABLE_SERIAL 0  // 1 = labelled output; 0 = CSV output for plotting
#define LOG_RAW_STREAM 1  // raw ECG/PPG records are emitted only in CSV mode
#define VITAL32_FIREBASE_TASK_STACK 20480
#define VITAL32_DEBUG_STACK 0

TwoWire I2CBusA = TwoWire(0);
TwoWire I2CBusB = TwoWire(1);
Adafruit_MPU6050 mpu;
Adafruit_BME680 bme(&I2CBusA);
Adafruit_MLX90614 mlx;
Adafruit_SSD1306 display(128, 64, &I2CBusA, -1);
MAX30105 max30102;

FallDetector fallDet;
StepCounter stepCnt;
HRVCalculator hrvCalc;
FeverTrend feverTrend;
MotorFeatureWindow motorFeatures;

struct SensorState {
  float ax = 0, ay = 0, az = 1;
  float gx = 0, gy = 0, gz = 0;
  float airTemp = NAN, humidity = NAN, pressure = NAN, gasResistance = NAN, altitude = NAN;
  float ambientTemp = NAN, objectTemp = NAN;
  float gsrRaw = NAN, uvRaw = 0;
  uint32_t red = 0, ir = 0;
  float hr = 0;
  bool hrValid = false;
  bool spo2Valid = false;
  bool fallActive = false;
  bool ecgLeadsOff = true;
  int ecgRaw = 0;
  int steps = 0;
  int potRaw = 0;
} s;

bool mpuReady = false, bmeReady = false, mlxReady = false;
bool displayReady = false, maxReady = false;
uint32_t lastEcgSample = 0, lastSensorRead = 0, lastDisplayUpdate = 0;
uint32_t lastFirebaseQueue = 0, fallLatchUntil = 0, lastBeatMs = 0;
uint32_t lastPpgLogMs = 0;
uint32_t bmeReadyAt = 0;
long lastBeatTime = 0;
float beatBuffer[5] = {0};
uint8_t beatIndex = 0, beatCount = 0;
int currentPage = -1;
QueueHandle_t firebaseQueue = nullptr;

struct FirebaseMessage {
  uint8_t type;
  Vital32Payload payload;
  float impactPeakG;
  unsigned long timestampMs;
};

static bool leadsOffNow() {
  return digitalRead(ECG_LO_MINUS_PIN) == HIGH || digitalRead(ECG_LO_PLUS_PIN) == HIGH;
}

static void queueVitals() {
  if (!firebaseQueue) return;
  FirebaseMessage msg = {};
  msg.type = 0;
  msg.payload.hr_valid = s.hrValid;
  msg.payload.hrv_valid = hrvCalc.valid;
  msg.payload.hrv_rmssd_ms = hrvCalc.valid ? hrvCalc.rmssdMs : 0;
  msg.payload.hrv_sdnn_ms = hrvCalc.valid ? hrvCalc.sdnnMs : 0;
  msg.payload.hr = s.hrValid ? s.hr : 0.0f;
  msg.payload.spo2_valid = s.spo2Valid;
  msg.payload.temp = isfinite(s.objectTemp) ? s.objectTemp : 0;
  msg.payload.steps = s.steps;
  msg.payload.gsr = isfinite(s.gsrRaw) ? s.gsrRaw : 0;
  msg.payload.gsr_verified = false;
  msg.payload.accel_x = s.ax;
  msg.payload.accel_y = s.ay;
  msg.payload.accel_z = s.az;
  msg.payload.gyro_x = s.gx;
  msg.payload.gyro_y = s.gy;
  msg.payload.gyro_z = s.gz;
  msg.payload.pressure = isfinite(s.pressure) ? s.pressure : 0;
  msg.payload.humidity = isfinite(s.humidity) ? s.humidity : 0;
  msg.payload.gas_resistance = isfinite(s.gasResistance) ? s.gasResistance : 0;
  msg.payload.altitude = isfinite(s.altitude) ? s.altitude : 0;
  msg.payload.uv_index = s.uvRaw;
  msg.payload.fall_detected = s.fallActive;
  msg.payload.ecg_leads_on = !s.ecgLeadsOff;
  msg.payload.timestamp_ms = millis();
  msg.payload.temp_trend_rate = isfinite(feverTrend.rateCPerHour) ? feverTrend.rateCPerHour : 0;
  msg.payload.temp_cusum = feverTrend.cusum;
  msg.payload.temp_trend_alert = feverTrend.trendAlert || feverTrend.cusumAlert;
  msg.payload.temp_baseline_ready = feverTrend.baselineReady;
  xQueueSend(firebaseQueue, &msg, 0);
}

static void queueFallEvent(float peakG, unsigned long ts) {
  if (!firebaseQueue) return;
  FirebaseMessage msg = {};
  msg.type = 1;
  msg.impactPeakG = peakG;
  msg.timestampMs = ts;
  xQueueSend(firebaseQueue, &msg, 0);
}

static void firebaseTask(void *parameter) {
  FirebaseMessage msg;
  for (;;) {
    if (firebaseQueue && xQueueReceive(firebaseQueue, &msg, pdMS_TO_TICKS(250)) == pdTRUE) {
      if (msg.type == 0) fbWriteVitals(msg.payload);
      else fbWriteFallEvent(msg.impactPeakG, msg.timestampMs);
    }
#if VITAL32_DEBUG_STACK
    static uint32_t lastStackLog = 0;
    if (millis() - lastStackLog > 30000) {
      lastStackLog = millis();
      Serial.printf("STACK,firebase,%u\n", uxTaskGetStackHighWaterMark(NULL));
    }
#endif
  }
}

static void initializeSensors() {
  mpuReady = mpu.begin(0x68, &I2CBusA);
  if (mpuReady) {
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  }

  bmeReady = bme.begin(0x77);
  if (bmeReady) {
    bme.setTemperatureOversampling(BME680_OS_8X);
    bme.setHumidityOversampling(BME680_OS_2X);
    bme.setPressureOversampling(BME680_OS_4X);
    bme.setIIRFilterSize(BME680_FILTER_SIZE_3);
    bme.setGasHeater(320, 150);
  }

  mlxReady = mlx.begin(0x5A, &I2CBusB);
  maxReady = max30102.begin(I2CBusB, I2C_SPEED_STANDARD);
  if (maxReady) {
    max30102.setup(0x1F, 4, 2, 100, 411, 4096);
    max30102.setPulseAmplitudeRed(0x1F);
    max30102.setPulseAmplitudeIR(0x1F);
    max30102.setPulseAmplitudeGreen(0);
  }

  displayReady = display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR, false, false);
  if (displayReady) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Vital32 booting");
    display.display();
  }

  Serial.printf("BOOT,MPU6050,%s\n", mpuReady ? "OK" : "FAIL");
  Serial.printf("BOOT,BME680_688,%s\n", bmeReady ? "OK" : "FAIL");
  Serial.printf("BOOT,MLX90614,%s\n", mlxReady ? "OK" : "FAIL");
  Serial.printf("BOOT,MAX30102,%s\n", maxReady ? "OK" : "FAIL");
  Serial.printf("BOOT,SSD1306,%s\n", displayReady ? "OK" : "FAIL");
}

static void readMotion() {
  if (!mpuReady) return;
  sensors_event_t a, g, t;
  mpu.getEvent(&a, &g, &t);
  s.ax = a.acceleration.x / 9.80665f;
  s.ay = a.acceleration.y / 9.80665f;
  s.az = a.acceleration.z / 9.80665f;
  s.gx = g.gyro.x;
  s.gy = g.gyro.y;
  s.gz = g.gyro.z;
  unsigned long now = millis();
  stepUpdate(stepCnt, s.ax, s.ay, s.az, now);
  motorFeatures.add(s.gx, s.gy, s.gz);
  const MotorFeatures& mf = motorFeatures.get();
  static float lastBandPower = -1.0f;
  if (mf.ready && mf.tremorBandPower != lastBandPower) {
    lastBandPower = mf.tremorBandPower;
#if !HUMAN_READABLE_SERIAL
    Serial.printf("MOTOR_FEATURE,%lu,%.5f,%.5f,%.5f\n", now, mf.gyroRms, mf.tremorBandPower, mf.tremorBandRatio);
#endif
  }
  if (fallUpdate(fallDet, s.ax, s.ay, s.az, now)) {
    s.fallActive = true;
    fallLatchUntil = now + FALL_LATCH_MS;
    queueFallEvent(fallDet.impactPeakG, now);
    fallDet.eventPending = false;
  }
  if (s.fallActive && (int32_t)(now - fallLatchUntil) >= 0) s.fallActive = false;
}

static void servicePpg() {
  if (!maxReady) return;
  max30102.check();
  while (max30102.available()) {
    uint32_t red = max30102.getRed();
    uint32_t ir = max30102.getIR();
    unsigned long now = millis();
    s.red = red;
    s.ir = ir;
    if (ir > 50000 && checkForBeat((long)ir)) {
      if (lastBeatTime > 0) {
        float interval = (float)(now - (unsigned long)lastBeatTime);
        hrvAddIBI(hrvCalc, (uint16_t)interval);
        float bpm = 60000.0f / interval;
        if (bpm >= 30 && bpm <= 200) {
          beatBuffer[beatIndex] = bpm;
          beatIndex = (beatIndex + 1) % 5;
          if (beatCount < 5) beatCount++;
          float total = 0;
          for (uint8_t i = 0; i < beatCount; i++) total += beatBuffer[i];
          s.hr = total / beatCount;
          s.hrValid = true;
          lastBeatMs = now;
        }
      }
      lastBeatTime = now;
    }
    if (s.hrValid && now - lastBeatMs > PPG_STALE_MS) s.hrValid = false;
#if LOG_RAW_STREAM && !HUMAN_READABLE_SERIAL
    Serial.printf("P,%lu,%lu,%lu\n", now, (unsigned long)red, (unsigned long)ir);
#endif
    max30102.nextSample();
  }
}

static void printHumanStatus() {
  Serial.println();
  Serial.println(F("========== VITAL32 STATUS =========="));
  Serial.printf("Uptime: %lu s\n", (unsigned long)(millis() / 1000UL));

  Serial.print(F("Heart rate: "));
  if (s.hrValid && isfinite(s.hr)) Serial.printf("%.1f BPM\n", s.hr);
  else Serial.println(F("unavailable (check finger placement / PPG signal)"));
  Serial.println(F("SpO2: not measured by this firmware"));
  if (hrvCalc.valid) Serial.printf("HRV RMSSD: %.1f ms | SDNN: %.1f ms\n", hrvCalc.rmssdMs, hrvCalc.sdnnMs);
  else Serial.println(F("HRV: collecting valid beat intervals"));

  Serial.print(F("Object temperature: "));
  if (isfinite(s.objectTemp)) Serial.printf("%.2f C\n", s.objectTemp);
  else Serial.println(F("unavailable"));
  Serial.print(F("Ambient temperature: "));
  if (isfinite(s.ambientTemp)) Serial.printf("%.2f C\n", s.ambientTemp);
  else Serial.println(F("unavailable"));

  Serial.print(F("Air temperature: "));
  if (isfinite(s.airTemp)) Serial.printf("%.2f C\n", s.airTemp);
  else Serial.println(F("unavailable - check BME680 wiring / reading"));
  Serial.print(F("Humidity: "));
  if (isfinite(s.humidity)) Serial.printf("%.1f %%\n", s.humidity);
  else Serial.println(F("unavailable"));
  Serial.print(F("Pressure: "));
  if (isfinite(s.pressure)) Serial.printf("%.2f hPa\n", s.pressure);
  else Serial.println(F("unavailable"));
  Serial.print(F("Gas resistance: "));
  if (isfinite(s.gasResistance)) Serial.printf("%.0f ohms\n", s.gasResistance);
  else Serial.println(F("unavailable"));

  Serial.printf("Acceleration: X %.2f, Y %.2f, Z %.2f g\n", s.ax, s.ay, s.az);
  Serial.printf("Gyroscope: X %.3f, Y %.3f, Z %.3f rad/s\n", s.gx, s.gy, s.gz);
  Serial.printf("Steps counted: %d\n", s.steps);
  Serial.printf("ECG ADC: %d / 4095 | leads: %s\n", s.ecgRaw,
                s.ecgLeadsOff ? "CHECK CONNECTION" : "no lead-off detected");
  Serial.printf("GSR raw ADC: %.0f / 4095 (not calibrated)\n", s.gsrRaw);
  Serial.printf("UV raw ADC: %.0f / 4095 (not converted to UV index)\n", s.uvRaw);
  Serial.printf("Fall alert: %s\n", s.fallActive ? "TRIGGERED - CHECK PERSON" : "none detected");

  Serial.printf("Sensor detection: MPU6050 %s | BME680 %s | MLX90614 %s | MAX3010x %s | OLED %s\n",
                mpuReady ? "OK" : "FAIL", bmeReady ? "OK" : "FAIL",
                mlxReady ? "OK" : "FAIL", maxReady ? "OK" : "FAIL",
                displayReady ? "OK" : "FAIL");
  Serial.printf("Temperature trend baseline: %s | trend alert: %s\n",
                feverTrend.baselineReady ? "READY" : "BUILDING",
                (feverTrend.trendAlert || feverTrend.cusumAlert) ? "YES - REVIEW TEMPERATURE" : "no");
  Serial.println(F("===================================="));
}

static void readSlowSensors() {
  if (bmeReady) {
    if (bmeReadyAt != 0 && (int32_t)(millis() - bmeReadyAt) >= 0) {
      if (bme.endReading()) {
        s.airTemp = bme.temperature;
        s.humidity = bme.humidity;
        s.pressure = bme.pressure / 100.0f;
        s.gasResistance = bme.gas_resistance;
        s.altitude = 44330.0f * (1.0f - powf(s.pressure / 1013.25f, 0.1903f));
      }
      bmeReadyAt = 0;
    }
    if (bmeReadyAt == 0) bmeReadyAt = bme.beginReading();
  }
  if (mlxReady) {
    float ambient = mlx.readAmbientTempC();
    float object = mlx.readObjectTempC();
    if (isfinite(ambient) && ambient > -40.0f && ambient < 125.0f) s.ambientTemp = ambient;
    if (isfinite(object) && object >= 10.0f && object <= 50.0f) {
      s.objectTemp = object;
      feverTrendAddReading(feverTrend, object, millis());
    }
  }
  uint32_t gsrSum = 0;
  uint32_t uvSum = 0;
  for (int i = 0; i < 16; i++) {
    gsrSum += analogRead(GSR_PIN);
    uvSum += analogRead(UV_PIN);
  }
  s.gsrRaw = gsrSum / 16.0f;
  s.uvRaw = uvSum / 16.0f;
  s.steps = stepGet(stepCnt);
  s.ecgLeadsOff = leadsOffNow();
#if HUMAN_READABLE_SERIAL
  printHumanStatus();
#else
  Serial.printf("T,%lu,%.3f,%.4f,%.3f,%d,%d,%s\n", millis(), s.objectTemp, feverTrend.rateCPerHour, feverTrend.cusum, feverTrend.baselineReady ? 1 : 0, (feverTrend.trendAlert || feverTrend.cusumAlert) ? 1 : 0, feverTrendLabel(feverTrend));
  Serial.printf("H,%lu,%d,%.2f,%.2f\n", millis(), hrvCalc.valid ? 1 : 0, hrvCalc.rmssdMs, hrvCalc.sdnnMs);
  Serial.printf("S,%lu,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%.0f,%.0f,%d\n",
    millis(), s.ax, s.ay, s.az, s.gx, s.gy, s.gz,
    s.airTemp, s.humidity, s.pressure, s.objectTemp, s.ambientTemp,
    s.gasResistance, s.steps, s.gsrRaw, s.uvRaw, s.ecgLeadsOff ? 1 : 0);
#endif
}

static int readPotPage() {
  s.potRaw = analogRead(POT_PIN);
  return constrain(s.potRaw / 1024, 0, 3);
}

static void updateDisplay() {
  if (!displayReady) return;
  int page = readPotPage();
  currentPage = page;
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  if (page == 0) {
    display.println("Vital32 / Overview");
    display.printf("HR: %s", s.hrValid ? "" : "--");
    if (s.hrValid) display.printf("%.0f BPM", s.hr); else display.print("BPM");
    display.println();
    display.println("SpO2: not calibrated");
    display.printf("Temp: %.1f C\n", isfinite(s.objectTemp) ? s.objectTemp : 0.0f);
    display.printf("Trend: %s\n", (feverTrend.trendAlert || feverTrend.cusumAlert) ? "CHECK TEMP" : (feverTrend.baselineReady ? "no alert" : "learning"));
    display.printf("Steps: %d\n", s.steps);
    display.printf("ECG leads: %s\n", s.ecgLeadsOff ? "OFF" : "ON");
  } else if (page == 1) {
    display.println("Vital32 / Motion");
    display.printf("A: %.2f %.2f %.2f g\n", s.ax, s.ay, s.az);
    display.printf("G: %.2f %.2f %.2f\n", s.gx, s.gy, s.gz);
    display.printf("Steps: %d\n", s.steps);
    display.printf("Fall: %s\n", s.fallActive ? "CHECK USER" : "none");
    const MotorFeatures& mf = motorFeatures.get();
    display.printf("Motor data: %s\n", mf.ready ? "READY" : "collecting");
    display.printf("Tremor ratio: %.2f\n", mf.ready ? mf.tremorBandRatio : 0.0f);
  } else if (page == 2) {
    display.println("Vital32 / Environment");
    display.printf("Air: %.1f C\n", isfinite(s.airTemp) ? s.airTemp : 0.0f);
    display.printf("Humidity: %.1f %%\n", isfinite(s.humidity) ? s.humidity : 0.0f);
    display.printf("Pressure: %.1f hPa\n", isfinite(s.pressure) ? s.pressure : 0.0f);
    display.printf("Gas raw: %.0f ohm\n", isfinite(s.gasResistance) ? s.gasResistance : 0.0f);
    display.printf("UV ADC: %.0f\n", s.uvRaw);
  } else {
    display.println("Vital32 / Raw");
    display.printf("ECG ADC: %d\n", s.ecgRaw);
    display.printf("GSR ADC: %.0f\n", s.gsrRaw);
    display.printf("IR: %lu\n", (unsigned long)s.ir);
    display.printf("RED: %lu\n", (unsigned long)s.red);
    display.printf("Firebase: %s\n", fbIsConnected() ? "WiFi up" : "offline");
  }
  display.setCursor(0, 56);
  display.print("Turn pot: page ");
  display.print(page + 1);
  display.print("/4");
  display.display();
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  analogReadResolution(12);
  pinMode(ECG_LO_MINUS_PIN, INPUT);
  pinMode(ECG_LO_PLUS_PIN, INPUT);
  pinMode(ECG_PIN, INPUT);
  pinMode(UV_PIN, INPUT);
  pinMode(GSR_PIN, INPUT);
  pinMode(POT_PIN, INPUT);

  I2CBusA.begin(I2C_A_SDA, I2C_A_SCL, 400000);
  I2CBusB.begin(I2C_B_SDA, I2C_B_SCL, 100000);
  delay(100);
#if HUMAN_READABLE_SERIAL
  Serial.println();
  Serial.println(F("Vital32 starting - readable serial mode"));
  Serial.println(F("Sensor boot results and a labelled report will follow."));
#else
  Serial.println("LOG_FORMAT,E=timestamp_ms,ecg_adc,leads_off;P=timestamp_ms,red,ir;S=timestamp_ms,sensors...;T=timestamp_ms,tempC,rateC_per_hour,cusum,baseline_ready,trend_alert,label;MOTOR_FEATURE=timestamp_ms,gyro_rms,tremor_band_power,tremor_band_ratio");
#endif
  initializeSensors();

  WiFi.mode(WIFI_STA);
  WiFi.begin(FB_WIFI_SSID, FB_WIFI_PASSWORD);

  firebaseQueue = xQueueCreate(8, sizeof(FirebaseMessage));
  if (firebaseQueue) xTaskCreate(firebaseTask, "vital32_firebase", VITAL32_FIREBASE_TASK_STACK, nullptr, 1, nullptr);
#if HUMAN_READABLE_SERIAL
  Serial.println(F("Wi-Fi: attempting to connect (status is reported by the Firebase module)"));
#else
  Serial.println("BOOT,WIFI,CONNECTING");
#endif
}

void loop() {
  uint32_t now = millis();

  fbWifiTick();

  servicePpg();

  if ((uint32_t)(now - lastEcgSample) >= ECG_SAMPLE_PERIOD_MS) {
    lastEcgSample = now;
    s.ecgRaw = analogRead(ECG_PIN);
    s.ecgLeadsOff = leadsOffNow();
#if LOG_RAW_STREAM && !HUMAN_READABLE_SERIAL
    Serial.printf("E,%lu,%d,%d\n", now, s.ecgRaw, s.ecgLeadsOff ? 1 : 0);
#endif
  }

  static uint32_t lastMotionRead = 0;
  if (now - lastMotionRead >= 20) {
    lastMotionRead = now;
    readMotion();
  }

  if (now - lastSensorRead >= SENSOR_PERIOD_MS) {
    lastSensorRead = now;
    readSlowSensors();
  }

  if (now - lastDisplayUpdate >= DISPLAY_PERIOD_MS) {
    lastDisplayUpdate = now;
    updateDisplay();
  }

  if (now - lastFirebaseQueue >= FIREBASE_PERIOD_MS) {
    lastFirebaseQueue = now;
    queueVitals();
  }
}
