#include <Arduino.h>
#include <Wire.h>
#include <math.h>
#include "driver/gpio.h"
#include <Adafruit_PWMServoDriver.h>
#include <BLEDevice.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

#define BEACON_UUID "7a1f0001-5c3e-4b8a-9d2e-1f6b8c0a4e11"

#define PIN_RPWM_L 4
#define PIN_LPWM_L 5
#define PIN_RPWM_R 6
#define PIN_LPWM_R 7
#define PIN_SDA 8
#define PIN_SCL 9
#define PIN_TRIG 18
#define PIN_ECHO 21

// BTS7960/IBT-2 active-HIGH enables. Drivers remain disabled at boot.
#define PIN_EN_R_L 15
#define PIN_EN_L_L 16
#define PIN_EN_R_R 17
#define PIN_EN_L_R 18
#define MPU_ADDR 0x68

#define PWM_FREQ 20000
#define PWM_RES 8
#define PWM_MAX 255
#define CONTROL_PERIOD_MS 10
#define WATCHDOG_MS 400
#define SONAR_PERIOD_MS 100
#define IMU_PERIOD_MS 10
#define STOP_CM 28.0f
#define CLEAR_CM 36.0f
#define KMAX 2.5f
#define DEADBAND 0.18f
#define STEER_STEP_DEG 3.0f
#define STEER_READY_DEG 4.0f
#define ACCEL_STEP 0.025f
#define DECEL_STEP 0.08f

const float HALF_L = 0.120f;
const float HALF_W = 0.100f;
const float MAX_STEER_DEG = 55.0f;
const float US_PER_DEG = 11.0f;
const int SERVO_TRIM_US[4] = {0, 0, 0, 0};
const int SERVO_DIR[4] = {1, 1, 1, 1};
const float MOTOR_DIR_L = 1.0f;
const float MOTOR_DIR_R = 1.0f;

const float WX[4] = {HALF_L, HALF_L, -HALF_L, -HALF_L};
const float WY[4] = {HALF_W, -HALF_W, HALF_W, -HALF_W};

const int PWM_PINS[4] = {PIN_RPWM_L, PIN_LPWM_L, PIN_RPWM_R, PIN_LPWM_R};

Adafruit_PWMServoDriver pca(0x40, Wire);
BLEScan* bleScan = nullptr;

volatile int8_t rssiBuf[32];
volatile uint8_t rssiHead = 0;
volatile uint8_t rssiTail = 0;

bool pcaOk = false;
bool armed = false;
bool blocked = false;
int nearCount = 0;
int cmdMode = 0;
float cmdSpeed = 0.0f;
float cmdCurv = 0.0f;
uint32_t lastCmdMs = 0;
float steerNow[4] = {0, 0, 0, 0};
float sideNow[2] = {0, 0};
uint32_t lastControl = 0;
uint32_t lastSonar = 0;
uint32_t lastImu = 0;
float gyroBiasZ = 0.0f;
float yawDeg = 0.0f;
bool imuOk = false;
uint32_t lastClear = 0;

class BeaconCb : public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice advertisedDevice) {
    if (!advertisedDevice.isAdvertisingService(BLEUUID(BEACON_UUID))) return;
    uint8_t nx = (rssiHead + 1) & 31;
    if (nx == rssiTail) return;
    rssiBuf[rssiHead] = (int8_t)advertisedDevice.getRSSI();
    rssiHead = nx;
  }
};

void pwmWrite(int idx, int duty) {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(PWM_PINS[idx], duty);
#else
  ledcWrite(idx, duty);
#endif
}

void pwmInit() {
  for (int i = 0; i < 4; i++) {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcAttach(PWM_PINS[i], PWM_FREQ, PWM_RES);
#else
    ledcSetup(i, PWM_FREQ, PWM_RES);
    ledcAttachPin(PWM_PINS[i], i);
#endif
    pwmWrite(i, 0);
  }
}

void driveSide(int side, float s) {
  float a = fabsf(s);
  int duty = 0;
  if (a > 0.02f) duty = (int)((DEADBAND + a * (1.0f - DEADBAND)) * PWM_MAX);
  duty = constrain(duty, 0, PWM_MAX);
  int r = side * 2;
  int l = side * 2 + 1;
  if (s >= 0.0f) {
    pwmWrite(l, 0);
    pwmWrite(r, duty);
  } else {
    pwmWrite(r, 0);
    pwmWrite(l, duty);
  }
}


void setDriverEnable(bool enabled) {
  uint8_t level = enabled ? HIGH : LOW;
  digitalWrite(PIN_EN_R_L, level);
  digitalWrite(PIN_EN_L_L, level);
  digitalWrite(PIN_EN_R_R, level);
  digitalWrite(PIN_EN_L_R, level);
}

bool mpuWriteReg(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool mpuReadBytes(uint8_t reg, uint8_t *dst, size_t count) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  size_t got = Wire.requestFrom((int)MPU_ADDR, (int)count, (int)true);
  if (got != count) return false;
  for (size_t i = 0; i < count; i++) dst[i] = Wire.read();
  return true;
}

int16_t be16(const uint8_t *p) {
  return (int16_t)(((uint16_t)p[0] << 8) | p[1]);
}

void imuInit() {
  // MPU6050 at 0x68, ±250 degrees/s, filtered gyro.
  imuOk = mpuWriteReg(0x6B, 0x00) &&
          mpuWriteReg(0x1B, 0x00) &&
          mpuWriteReg(0x1A, 0x03);
  Serial.printf("BOOT,MPU6050,%s\n", imuOk ? "OK" : "FAIL");
  if (!imuOk) return;

  // Keep the rover stationary during this startup bias measurement.
  double sum = 0.0;
  int valid = 0;
  for (int i = 0; i < 150; i++) {
    uint8_t raw[14];
    if (mpuReadBytes(0x3B, raw, sizeof(raw))) {
      sum += be16(raw + 12) / 131.0; // gyro Z in deg/s
      valid++;
    }
    delay(10);
  }
  if (valid > 0) gyroBiasZ = (float)(sum / valid);
  Serial.printf("BOOT,GYRO_BIAS,%.4f\n", gyroBiasZ);
}

void imuStep(uint32_t now) {
  static uint32_t previousMs = 0;
  if (!imuOk) return;
  uint8_t raw[14];
  if (!mpuReadBytes(0x3B, raw, sizeof(raw))) return;
  float rateZ = be16(raw + 12) / 131.0f - gyroBiasZ;
  if (previousMs != 0) {
    float dt = (now - previousMs) / 1000.0f;
    if (dt > 0.0f && dt < 0.1f) yawDeg += rateZ * dt;
  }
  previousMs = now;
  Serial.printf("G,%.2f\n", yawDeg);
}

void servoWrite(int i, float deg) {
  float us = 1500.0f + SERVO_TRIM_US[i] + SERVO_DIR[i] * deg * US_PER_DEG;
  us = constrain(us, 700.0f, 2300.0f);
  pca.writeMicroseconds(i, (uint16_t)us);
}

void steerInit() {
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.beginTransmission(0x40);
  pcaOk = (Wire.endTransmission() == 0);
  Serial.printf("BOOT,PCA9685,%s\n", pcaOk ? "OK" : "FAIL");
  if (!pcaOk) return;
  Wire.setClock(400000);
  pca.reset();
  delay(10);
  pca.setOscillatorFrequency(27000000);
  pca.setPWMFreq(50);
  for (int i = 0; i < 4; i++) servoWrite(i, 0.0f);
}

void wheelKin(float cx, float cy, int i, float omega, float &angDeg, float &spd) {
  float rx = WX[i] - cx;
  float ry = WY[i] - cy;
  float vx = -omega * ry;
  float vy = omega * rx;
  float mag = sqrtf(vx * vx + vy * vy);
  float a = atan2f(vy, vx);
  float dir = 1.0f;
  if (a > HALF_PI) {
    a -= PI;
    dir = -1.0f;
  } else if (a < -HALF_PI) {
    a += PI;
    dir = -1.0f;
  }
  angDeg = a * RAD_TO_DEG;
  spd = dir * mag;
}

void computeTargets(int mode, float cmd, float k, float ang[4], float spd[4]) {
  if (mode == 1) {
    for (int i = 0; i < 4; i++) wheelKin(0.0f, 0.0f, i, 1.0f, ang[i], spd[i]);
  } else if (fabsf(k) < 0.02f) {
    for (int i = 0; i < 4; i++) {
      ang[i] = 0.0f;
      spd[i] = 1.0f;
    }
  } else {
    float R = 1.0f / k;
    for (int i = 0; i < 4; i++) wheelKin(0.0f, R, i, k, ang[i], spd[i]);
  }
  float m = 0.0f;
  for (int i = 0; i < 4; i++) {
    if (fabsf(spd[i]) > m) m = fabsf(spd[i]);
    if (ang[i] > MAX_STEER_DEG) ang[i] = MAX_STEER_DEG;
    if (ang[i] < -MAX_STEER_DEG) ang[i] = -MAX_STEER_DEG;
  }
  for (int i = 0; i < 4; i++) spd[i] = (m > 1e-6f) ? spd[i] / m * cmd : 0.0f;
}

float slew(float cur, float tgt) {
  float step = fabsf(tgt) < fabsf(cur) ? DECEL_STEP : ACCEL_STEP;
  float d = tgt - cur;
  if (d > step) d = step;
  if (d < -step) d = -step;
  return cur + d;
}

void controlStep() {
  float cs = cmdSpeed;
  bool commandFresh = (millis() - lastCmdMs) <= WATCHDOG_MS;
  bool motorPermit = armed && commandFresh && pcaOk && imuOk;
  setDriverEnable(motorPermit);
  if (!motorPermit) cs = 0.0f;
  if (cmdMode == 0 && cs > 0.0f && blocked) cs = 0.0f;
  float ang[4];
  float spd[4];
  computeTargets(cmdMode, cs, cmdCurv, ang, spd);
  if (pcaOk) {
    for (int i = 0; i < 4; i++) {
      float d = ang[i] - steerNow[i];
      if (d > STEER_STEP_DEG) d = STEER_STEP_DEG;
      if (d < -STEER_STEP_DEG) d = -STEER_STEP_DEG;
      steerNow[i] += d;
      servoWrite(i, steerNow[i]);
    }
  }
  bool ready = pcaOk;
  for (int i = 0; i < 4 && ready; i++) {
    if (fabsf(ang[i] - steerNow[i]) > STEER_READY_DEG) ready = false;
  }
  float tl = 0.0f;
  float tr = 0.0f;
  if (ready) {
    tl = (spd[0] + spd[2]) * 0.5f * MOTOR_DIR_L;
    tr = (spd[1] + spd[3]) * 0.5f * MOTOR_DIR_R;
  }
  sideNow[0] = slew(sideNow[0], tl);
  sideNow[1] = slew(sideNow[1], tr);
  driveSide(0, sideNow[0]);
  driveSide(1, sideNow[1]);
}

float readSonarCm() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(3);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);
  unsigned long us = pulseIn(PIN_ECHO, HIGH, 12000);
  if (us == 0) return 999.0f;
  return us / 58.0f;
}

void sonarStep() {
  float cm = readSonarCm();
  if (cm < STOP_CM) {
    if (nearCount < 3) nearCount++;
  } else if (cm > CLEAR_CM) {
    nearCount = 0;
  }
  blocked = nearCount >= 2;
  Serial.printf("U,%.1f,%d\n", cm, blocked ? 1 : 0);
}

void drainRssi() {
  while (rssiTail != rssiHead) {
    int r = rssiBuf[rssiTail];
    rssiTail = (rssiTail + 1) & 31;
    Serial.printf("B,%d\n", r);
  }
}

void handleLine(char* line) {
  if (line[0] == 'C') {
    int m;
    float s;
    float k;
    if (sscanf(line, "C,%d,%f,%f", &m, &s, &k) == 3) {
      cmdMode = (m == 1) ? 1 : 0;
      cmdSpeed = constrain(s, -1.0f, 1.0f);
      cmdCurv = constrain(k, -KMAX, KMAX);
      lastCmdMs = millis();
    }
  } else if (line[0] == 'S') {
    cmdSpeed = 0.0f;
    lastCmdMs = millis();
  } else if (line[0] == 'A') {
    int a;
    if (sscanf(line, "A,%d", &a) == 1) {
      armed = (a == 1) && pcaOk && imuOk;
      cmdSpeed = 0.0f;
      setDriverEnable(false);
      lastCmdMs = millis();
      Serial.printf("STATUS,ARMED,%d\n", armed ? 1 : 0);
    }
  }
}

void pollSerial() {
  static char buf[64];
  static int n = 0;
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (n > 0) {
        buf[n] = 0;
        handleLine(buf);
      }
      n = 0;
    } else if (n < (int)sizeof(buf) - 1) {
      buf[n++] = c;
    }
  }
}

void bleStart() {
  BLEDevice::init("");
  bleScan = BLEDevice::getScan();
  bleScan->setAdvertisedDeviceCallbacks(new BeaconCb(), true);
  bleScan->setActiveScan(false);
  bleScan->setInterval(100);
  bleScan->setWindow(99);
  bleScan->start(0, nullptr, false);
  Serial.println("BOOT,BLE,SCANNING");
}

void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(PIN_TRIG, OUTPUT);
  digitalWrite(PIN_TRIG, LOW);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_EN_R_L, OUTPUT);
  pinMode(PIN_EN_L_L, OUTPUT);
  pinMode(PIN_EN_R_R, OUTPUT);
  pinMode(PIN_EN_L_R, OUTPUT);
  setDriverEnable(false);
  pwmInit();
  steerInit();
  imuInit();
  bleStart();
  Serial.println("BOOT,MOTOR,READY");
}

void loop() {
  uint32_t now = millis();
  pollSerial();
  drainRssi();
  if (now - lastControl >= CONTROL_PERIOD_MS) {
    lastControl = now;
    controlStep();
  }
  if (now - lastSonar >= SONAR_PERIOD_MS) {
    lastSonar = now;
    sonarStep();
  }
  if (now - lastImu >= IMU_PERIOD_MS) {
    lastImu = now;
    imuStep(now);
  }
  if (now - lastClear >= 15000) {
    lastClear = now;
    bleScan->clearResults();
  }
}