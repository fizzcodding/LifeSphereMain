/*
  Vital32 standalone sensor test
  Board: classic ESP32 DevKit (30-pin)

  I2C bus A: GPIO21 SDA / GPIO22 SCL
    OLED SSD1306 0x3C, MPU6050 0x68, BME680/688 0x77
  I2C bus B: GPIO19 SDA / GPIO18 SCL
    MAX30102 0x57, MLX90614 0x5A

  Analog inputs:
    ECG signal GPIO32; ECG LO- GPIO33; ECG LO+ GPIO25
    UV analog GPIO36; potentiometer wiper GPIO34; GSR analog GPIO35

  Libraries required:
    Adafruit GFX Library
    Adafruit SSD1306
    Adafruit MPU6050
    Adafruit Unified Sensor
    Adafruit BME680 Library
    Adafruit MLX90614 Library
    SparkFun MAX3010x Pulse and Proximity Sensor Library
*/

#include <Arduino.h>
#include <Wire.h>
#include <math.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME680.h>
#include <Adafruit_MLX90614.h>
#include <MAX30105.h>
#include "heartRate.h"

// I2C pins and addresses
static constexpr int I2C_A_SDA = 21;
static constexpr int I2C_A_SCL = 22;
static constexpr int I2C_B_SDA = 19;
static constexpr int I2C_B_SCL = 18;
static constexpr uint8_t OLED_ADDR = 0x3C;
static constexpr uint8_t MPU_ADDR = 0x68;
static constexpr uint8_t BME_ADDR = 0x77;
static constexpr uint8_t MLX_ADDR = 0x5A;

// Analog pins (classic ESP32 DevKit)
static constexpr int ECG_PIN = 32;
static constexpr int ECG_LO_MINUS_PIN = 33;
static constexpr int ECG_LO_PLUS_PIN = 25;
static constexpr int UV_PIN = 36;
static constexpr int POT_PIN = 34;
static constexpr int GSR_PIN = 35;

Adafruit_SSD1306 display(128, 64, &Wire, -1);
Adafruit_MPU6050 mpu;
Adafruit_BME680 bme(&Wire);
Adafruit_MLX90614 mlx;
MAX30105 max30102;

bool oledOK = false;
bool mpuOK = false;
bool bmeOK = false;
bool mlxOK = false;
bool maxOK = false;

float axG = 0, ayG = 0, azG = 1;
float gx = 0, gy = 0, gz = 0;
float airC = NAN, humidity = NAN, pressureHpa = NAN, gasKOhm = NAN;
float ambientC = NAN, objectC = NAN;
float bpm = NAN;
bool bpmValid = false;
uint32_t redValue = 0, irValue = 0;
int ecgRaw = 0, gsrRaw = 0, uvRaw = 0, potRaw = 0;
bool ecgLeadsOff = true;

float bpmBuffer[5] = {0};
uint8_t bpmIndex = 0;
uint8_t bpmCount = 0;
uint32_t lastBeatMs = 0;
uint32_t lastBeatTime = 0;
uint32_t lastMotionMs = 0;
uint32_t lastSlowReadMs = 0;
uint32_t lastDisplayMs = 0;
uint32_t lastSerialMs = 0;
uint32_t lastAnalogMs = 0;
int currentPage = 0;

bool leadsOff() {
  return digitalRead(ECG_LO_MINUS_PIN) == HIGH || digitalRead(ECG_LO_PLUS_PIN) == HIGH;
}

void initializeSensors() {
  // OLED and MPU/BME share I2C bus A.
  oledOK = display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR);
  if (oledOK) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("Vital32 sensor test");
    display.println("Starting sensors...");
    display.display();
  }

  mpuOK = mpu.begin(MPU_ADDR, &Wire);
  if (mpuOK) {
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  }

  bmeOK = bme.begin(BME_ADDR);
  if (bmeOK) {
    bme.setTemperatureOversampling(BME680_OS_8X);
    bme.setHumidityOversampling(BME680_OS_2X);
    bme.setPressureOversampling(BME680_OS_4X);
    bme.setIIRFilterSize(BME680_FILTER_SIZE_3);
    bme.setGasHeater(320, 150);
  }

  // MLX90614 and MAX30102 share I2C bus B.
  mlxOK = mlx.begin(MLX_ADDR, &Wire1);
  maxOK = max30102.begin(Wire1, I2C_SPEED_STANDARD);
  if (maxOK) {
    max30102.setup(0x1F, 4, 2, 100, 411, 4096);
    max30102.setPulseAmplitudeRed(0x1F);
    max30102.setPulseAmplitudeIR(0x1F);
    max30102.setPulseAmplitudeGreen(0);
  }

  Serial.println();
  Serial.println(F("========== VITAL32 SENSOR TEST =========="));
  Serial.printf("OLED SSD1306  0x3C: %s\n", oledOK ? "OK" : "FAIL");
  Serial.printf("MPU6050       0x68: %s\n", mpuOK ? "OK" : "FAIL");
  Serial.printf("BME680/688    0x77: %s\n", bmeOK ? "OK" : "FAIL");
  Serial.printf("MLX90614      0x5A: %s\n", mlxOK ? "OK" : "FAIL");
  Serial.printf("MAX30102      0x57: %s\n", maxOK ? "OK" : "FAIL");
  Serial.println(F("========================================="));
}

void readPPG() {
  if (!maxOK) return;
  max30102.check();
  while (max30102.available()) {
    redValue = max30102.getRed();
    irValue = max30102.getIR();
    const uint32_t now = millis();

    // Require a substantial IR signal before treating beats as finger data.
    if (irValue > 50000 && checkForBeat((long)irValue)) {
      if (lastBeatTime != 0) {
        const uint32_t interval = now - lastBeatTime;
        if (interval > 0) {
          const float candidate = 60000.0f / (float)interval;
          if (candidate >= 30.0f && candidate <= 200.0f) {
            bpmBuffer[bpmIndex] = candidate;
            bpmIndex = (bpmIndex + 1) % 5;
            if (bpmCount < 5) bpmCount++;
            float sum = 0;
            for (uint8_t i = 0; i < bpmCount; i++) sum += bpmBuffer[i];
            bpm = sum / bpmCount;
            bpmValid = true;
            lastBeatMs = now;
          }
        }
      }
      lastBeatTime = now;
    }
    max30102.nextSample();
  }
  if (bpmValid && millis() - lastBeatMs > 5000) bpmValid = false;
}

void readMotion() {
  if (!mpuOK) return;
  sensors_event_t accel, gyro, temp;
  mpu.getEvent(&accel, &gyro, &temp);
  axG = accel.acceleration.x / 9.80665f;
  ayG = accel.acceleration.y / 9.80665f;
  azG = accel.acceleration.z / 9.80665f;
  gx = gyro.gyro.x;
  gy = gyro.gyro.y;
  gz = gyro.gyro.z;
}

void readSensors() {
  if (bmeOK && bme.performReading()) {
    airC = bme.temperature;
    humidity = bme.humidity;
    pressureHpa = bme.pressure / 100.0f;
    gasKOhm = bme.gas_resistance / 1000.0f;
  }

  if (mlxOK) {
    const float amb = mlx.readAmbientTempC();
    const float obj = mlx.readObjectTempC();
    if (isfinite(amb) && amb > -40 && amb < 125) ambientC = amb;
    if (isfinite(obj) && obj > -40 && obj < 380) objectC = obj;
  }

  // Average analog inputs to reduce a little noise.
  uint32_t gsrSum = 0, uvSum = 0;
  for (int i = 0; i < 8; i++) {
    gsrSum += analogRead(GSR_PIN);
    uvSum += analogRead(UV_PIN);
  }
  gsrRaw = (int)(gsrSum / 8);
  uvRaw = (int)(uvSum / 8);
  ecgRaw = analogRead(ECG_PIN);
  ecgLeadsOff = leadsOff();
}

int readPotPage() {
  potRaw = analogRead(POT_PIN);
  // ADC is 0..4095. Four ranges select pages 0..3.
  return constrain((long)potRaw * 4L / 4096L, 0, 3);
}

void drawDisplay() {
  if (!oledOK) return;
  currentPage = readPotPage();
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);

  if (currentPage == 0) {
    display.println(F("Vital32 / Vitals"));
    display.print(F("BPM: "));
    if (bpmValid) display.println(bpm, 0); else display.println(F("-- (finger?)"));
    display.print(F("Object: "));
    if (isfinite(objectC)) display.print(objectC, 1); else display.print(F("--"));
    display.println(F(" C"));
    display.print(F("Ambient: "));
    if (isfinite(ambientC)) display.print(ambientC, 1); else display.print(F("--"));
    display.println(F(" C"));
    display.print(F("IR: ")); display.println(irValue);
    display.print(F("RED: ")); display.println(redValue);
  } else if (currentPage == 1) {
    display.println(F("Vital32 / Motion"));
    display.printf("Accel g %.2f %.2f\n", axG, ayG);
    display.printf("       z %.2f\n", azG);
    display.printf("Gyro  %.2f %.2f\n", gx, gy);
    display.printf("      z %.2f rad/s\n", gz);
    display.printf("MPU: %s\n", mpuOK ? "OK" : "FAIL");
  } else if (currentPage == 2) {
    display.println(F("Vital32 / Environment"));
    display.print(F("Air: ")); if (isfinite(airC)) display.print(airC, 1); else display.print(F("--")); display.println(F(" C"));
    display.print(F("Humidity: ")); if (isfinite(humidity)) display.print(humidity, 1); else display.print(F("--")); display.println(F(" %"));
    display.print(F("Pressure: ")); if (isfinite(pressureHpa)) display.print(pressureHpa, 1); else display.print(F("--")); display.println(F(" hPa"));
    display.print(F("Gas: ")); if (isfinite(gasKOhm)) display.print(gasKOhm, 1); else display.print(F("--")); display.println(F(" kOhm"));
  } else {
    display.println(F("Vital32 / Analog"));
    display.printf("ECG: %d  Leads:%s\n", ecgRaw, ecgLeadsOff ? "OFF" : "ON");
    display.printf("GSR raw: %d\n", gsrRaw);
    display.printf("UV raw: %d\n", uvRaw);
    display.printf("Pot: %d\n", potRaw);
    display.printf("Buses A/B: %s/%s\n", (mpuOK && bmeOK) ? "OK" : "check", (mlxOK && maxOK) ? "OK" : "check");
  }
  display.setCursor(0, 56);
  display.printf("Turn pot: page %d/4", currentPage + 1);
  display.display();
}

void printStatus() {
  Serial.println();
  Serial.println(F("------------ LIVE READINGS ------------"));
  Serial.printf("Uptime: %lu s | Page: %d | Pot ADC: %d\n", millis() / 1000, currentPage + 1, potRaw);
  Serial.printf("BPM: ");
  if (bpmValid) Serial.printf("%.1f\n", bpm); else Serial.println(F("not ready - place finger steadily on MAX30102"));
  Serial.printf("PPG IR: %lu | RED: %lu\n", (unsigned long)irValue, (unsigned long)redValue);
  Serial.printf("MPU6050: %s | Accel: %.3f, %.3f, %.3f g | Gyro: %.3f, %.3f, %.3f rad/s\n",
    mpuOK ? "OK" : "FAIL", axG, ayG, azG, gx, gy, gz);
  Serial.printf("BME680/688: %s | Air: %.2f C | RH: %.2f %% | Pressure: %.2f hPa | Gas: %.2f kOhm\n",
    bmeOK ? "OK" : "FAIL", airC, humidity, pressureHpa, gasKOhm);
  Serial.printf("MLX90614: %s | Ambient: %.2f C | Object: %.2f C\n", mlxOK ? "OK" : "FAIL", ambientC, objectC);
  Serial.printf("ECG: %d ADC | Leads off: %s | GSR: %d ADC | UV: %d ADC\n", ecgRaw, ecgLeadsOff ? "YES" : "NO", gsrRaw, uvRaw);
  Serial.printf("Init flags: OLED=%d MPU=%d BME=%d MLX=%d MAX=%d\n", oledOK, mpuOK, bmeOK, mlxOK, maxOK);
  Serial.println(F("---------------------------------------"));
}

void setup() {
  Serial.begin(115200);
  delay(500);
  analogReadResolution(12);
  pinMode(ECG_PIN, INPUT);
  pinMode(ECG_LO_MINUS_PIN, INPUT);
  pinMode(ECG_LO_PLUS_PIN, INPUT);
  pinMode(GSR_PIN, INPUT);
  pinMode(UV_PIN, INPUT);
  pinMode(POT_PIN, INPUT);

  // Use the standard ESP32 Wire objects, matching the known-working scanner.
  Wire.begin(I2C_A_SDA, I2C_A_SCL, 100000);
  Wire1.begin(I2C_B_SDA, I2C_B_SCL, 100000);
  delay(100);

  Serial.println(F("Vital32 standalone sensor test booting..."));
  initializeSensors();
}

void loop() {
  const uint32_t now = millis();
  readPPG();

  if (now - lastMotionMs >= 20) {
    lastMotionMs = now;
    readMotion();
  }
  if (now - lastAnalogMs >= 20) {
    lastAnalogMs = now;
    ecgRaw = analogRead(ECG_PIN);
    ecgLeadsOff = leadsOff();
  }
  if (now - lastSlowReadMs >= 1000) {
    lastSlowReadMs = now;
    readSensors();
  }
  if (now - lastDisplayMs >= 250) {
    lastDisplayMs = now;
    drawDisplay();
  }
  if (now - lastSerialMs >= 1000) {
    lastSerialMs = now;
    printStatus();
  }
}