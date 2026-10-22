#include <Arduino.h>
#include <Wire.h>
#include <math.h>
#include <Adafruit_PWMServoDriver.h>
#include <BLEDevice.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

#define PIN_RPWM_L 4
#define PIN_LPWM_L 5
#define PIN_RPWM_R 6
#define PIN_LPWM_R 7
#define PIN_SDA 8
#define PIN_SCL 9
#define PIN_TRIG 18
#define PIN_ECHO 12

#define PIN_EN_R_L 15
#define PIN_EN_L_L 16
#define PIN_EN_R_R 17
#define PIN_EN_L_R 14

#define BEACON_UUID "7a1f0001-5c3e-4b8a-9d2e-1f6b8c0a4e11"
#define BEACON_NAME "HollowRover-Beacon"
#define I2C_HZ 100000
#define PWM_FREQ 20000
#define PWM_RES 8
#define PWM_MAX 255
#define CONTROL_PERIOD_MS 10
#define WATCHDOG_MS 400
#define SONAR_PERIOD_MS 100
#define IMU_PERIOD_MS 10
#define STATUS_PERIOD_MS 300
#define STOP_CM 28.0f
#define CLEAR_CM 36.0f
#define KMAX 2.5f
#define DEADBAND 0.18f
#define STEER_STEP_DEG 2.0f
#define STEER_READY_DEG 3.0f
#define ACCEL_STEP 0.025f
#define DECEL_STEP 0.08f
#define HOMING_SPEED 0.22f
#define HOMING_TURN_SPEED 0.18f
#define HOMING_SWEEP_DEG 360.0f
#define HOMING_TARGET_RSSI -48
#define HOMING_LOST_MS 2500
#define HOMING_RESCAN_DROP_DB 15
#define SPIN_YAW_SIGN 1.0f

const float HALF_L = 0.120f;
const float HALF_W = 0.100f;
const float MAX_STEER_DEG = 35.0f;
const float US_PER_DEG = 11.0f;
const int SERVO_TRIM_US[4] = {0, 0, 0, 0};
const int SERVO_DIR[4] = {1, 1, 1, 1};
const float MOTOR_DIR_L = 1.0f;
const float MOTOR_DIR_R = 1.0f;

const float WX[4] = {HALF_L, HALF_L, -HALF_L, -HALF_L};
const float WY[4] = {HALF_W, -HALF_W, HALF_W, -HALF_W};
const int PWM_PINS[4] = {PIN_RPWM_L, PIN_LPWM_L, PIN_RPWM_R, PIN_LPWM_R};

Adafruit_PWMServoDriver pca(0x40, Wire);
bool pcaOk = false;
bool armed = false;
bool blocked = false;
bool humanLog = true;
int nearCount = 0;
float lastCm = 999.0f;
float cmdSpeed = 0.0f;
float cmdCurv = 0.0f;
uint32_t lastCmdMs = 0;
float steerNow[4] = {0, 0, 0, 0};
float sideNow[2] = {0, 0};
uint32_t lastControl = 0;
uint32_t lastSonar = 0;
uint32_t lastImu = 0;
uint32_t lastStatus = 0;
float gyroBiasZ = 0.0f;
float yawDeg = 0.0f;
bool imuOk = false;
uint8_t mpuAddr = 0x68;

BLEScan *bleScan = nullptr;
bool bleOk = false;
volatile int latestRssi = -127;
volatile uint32_t lastBeaconMs = 0;
volatile uint32_t beaconSequence = 0;
volatile uint32_t advSeen = 0;
volatile uint32_t beaconHits = 0;
volatile uint32_t scanCbCount = 0;
uint32_t consumedBeaconSequence = 0;
bool homing = false;
enum HomeState { HOME_IDLE, HOME_SWEEP, HOME_TURN, HOME_APPROACH, HOME_BLOCKED, HOME_ARRIVED };
HomeState homeState = HOME_IDLE;
float sweepStartYaw = 0.0f;
float bestYaw = 0.0f;
int bestRssi = -127;
uint32_t homeStateSince = 0;
uint32_t lastHomeTelemetry = 0;
uint32_t strongRssiSince = 0;

class BeaconCallbacks : public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice advertisedDevice) override {
    advSeen++;
    bool match = false;
    if (advertisedDevice.haveServiceUUID() &&
        advertisedDevice.isAdvertisingService(BLEUUID(BEACON_UUID))) match = true;
    if (!match && advertisedDevice.haveName() &&
        advertisedDevice.getName() == BEACON_NAME) match = true;
    if (match) {
      latestRssi = advertisedDevice.getRSSI();
      lastBeaconMs = millis();
      beaconHits++;
      beaconSequence++;
    }
  }
};

const char *homeStateName(HomeState s) {
  switch (s) {
    case HOME_SWEEP: return "SWEEP";
    case HOME_TURN: return "TURN";
    case HOME_APPROACH: return "APPROACH";
    case HOME_BLOCKED: return "BLOCKED";
    case HOME_ARRIVED: return "ARRIVED";
    default: return "IDLE";
  }
}

float wrap180(float a) {
  while (a > 180.0f) a -= 360.0f;
  while (a < -180.0f) a += 360.0f;
  return a;
}

void setHomeState(HomeState s) {
  homeState = s;
  homeStateSince = millis();
  if (humanLog) Serial.printf(">> HOME STATE: %s\n", homeStateName(s));
  else Serial.printf("HOME,%s\n", homeStateName(s));
}

void startHoming() {
  if (!pcaOk || !imuOk || !bleOk) {
    if (humanLog) {
      Serial.printf(">> HOME REFUSED | PCA %s | MPU %s | BLE %s\n",
                    pcaOk ? "ok" : "MISSING", imuOk ? "ok" : "MISSING", bleOk ? "ok" : "MISSING");
    } else {
      Serial.println("HOME,ERROR,NEED_PCA_MPU_BLE");
    }
    homing = false;
    armed = false;
    cmdSpeed = 0.0f;
    setDriverEnable(false);
    return;
  }
  homing = true;
  armed = true;
  cmdSpeed = 0.0f;
  cmdCurv = 0.0f;
  lastCmdMs = millis();
  bestRssi = -127;
  bestYaw = yawDeg;
  consumedBeaconSequence = beaconSequence;
  sweepStartYaw = yawDeg;
  strongRssiSince = 0;
  setHomeState(HOME_SWEEP);
  Serial.println("HOME,STARTED,KEEP_AREA_CLEAR");
}

void stopHoming() {
  homing = false;
  cmdSpeed = 0.0f;
  cmdCurv = 0.0f;
  armed = false;
  setDriverEnable(false);
  sideNow[0] = sideNow[1] = 0.0f;
  driveSide(0, 0.0f);
  driveSide(1, 0.0f);
  setHomeState(HOME_IDLE);
}

void onScanComplete(BLEScanResults results) {
  (void)results;
  scanCbCount++;
  if (bleScan) {
    bleScan->clearResults();
    bleScan->start(1, onScanComplete, false);
  }
}

void bleInit() {
  BLEDevice::init("HollowRover-S3");
  bleScan = BLEDevice::getScan();
  if (!bleScan) {
    Serial.println("BOOT,BLE,FAIL");
    return;
  }
  bleScan->setAdvertisedDeviceCallbacks(new BeaconCallbacks(), true);
  bleScan->setActiveScan(true);
  bleScan->setInterval(100);
  bleScan->setWindow(80);
  bleOk = bleScan->start(1, onScanComplete, false);
  Serial.printf("BOOT,BLE,%s\n", bleOk ? "SCANNING" : "START_FAIL");
}

void bleWatchdog(uint32_t now) {
  static uint32_t lastCheck = 0;
  static uint32_t lastCount = 0;
  if (!bleOk || !bleScan || now - lastCheck < 4000) return;
  lastCheck = now;
  uint32_t c = scanCbCount;
  if (c == lastCount) {
    bleScan->stop();
    bleScan->clearResults();
    bleScan->start(1, onScanComplete, false);
    Serial.println("BLE,SCAN_RESTART");
  }
  lastCount = c;
}

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

void setDriverEnable(bool enabled) {
  uint8_t level = enabled ? HIGH : LOW;
  digitalWrite(PIN_EN_R_L, level);
  digitalWrite(PIN_EN_L_L, level);
  digitalWrite(PIN_EN_R_R, level);
  digitalWrite(PIN_EN_L_R, level);
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

void i2cInit() {
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(I2C_HZ);
}

bool i2cProbe(uint8_t addr) {
  Wire.beginTransmission(addr);
  return Wire.endTransmission() == 0;
}

void scanI2C() {
  Serial.println("---- I2C SCAN (SDA=GPIO8, SCL=GPIO9) ----");
  int found = 0;
  for (uint8_t a = 1; a < 127; a++) {
    if (i2cProbe(a)) {
      found++;
      const char *n = "unknown device";
      if (a == 0x40) n = "PCA9685 servo driver";
      else if (a == 0x68 || a == 0x69) n = "MPU6050 (or clone)";
      else if (a == 0x70) n = "PCA9685 all-call";
      Serial.printf("  0x%02X  %s\n", a, n);
    }
  }
  if (found == 0) Serial.println("  NOTHING FOUND: check power, GND, SDA/SCL wiring");
  Serial.println("------------------------------------------");
}

bool mpuWriteReg(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(mpuAddr);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool mpuReadBytes(uint8_t reg, uint8_t *dst, size_t count) {
  Wire.beginTransmission(mpuAddr);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  size_t got = Wire.requestFrom((int)mpuAddr, (int)count, (int)true);
  if (got != count) return false;
  for (size_t i = 0; i < count; i++) dst[i] = Wire.read();
  return true;
}

int16_t be16(const uint8_t *p) {
  return (int16_t)(((uint16_t)p[0] << 8) | p[1]);
}

void imuInit() {
  imuOk = false;
  if (i2cProbe(0x68)) mpuAddr = 0x68;
  else if (i2cProbe(0x69)) mpuAddr = 0x69;
  else {
    Serial.println("BOOT,MPU6050,NOT_FOUND (tried 0x68 and 0x69)");
    return;
  }
  uint8_t who = 0;
  mpuReadBytes(0x75, &who, 1);
  Serial.printf("BOOT,MPU_ADDR,0x%02X,WHO_AM_I,0x%02X\n", mpuAddr, who);
  imuOk = mpuWriteReg(0x6B, 0x00) && mpuWriteReg(0x1B, 0x00) && mpuWriteReg(0x1A, 0x03);
  Serial.printf("BOOT,MPU6050,%s\n", imuOk ? "OK" : "FAIL");
  if (!imuOk) return;
  double sum = 0.0;
  int valid = 0;
  for (int i = 0; i < 150; i++) {
    uint8_t raw[14];
    if (mpuReadBytes(0x3B, raw, sizeof(raw))) {
      sum += be16(raw + 12) / 131.0;
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
  if (!humanLog) Serial.printf("G,%.2f\n", yawDeg);
}

void servoWrite(int i, float deg) {
  deg = constrain(deg, -MAX_STEER_DEG, MAX_STEER_DEG);
  float us = 1500.0f + SERVO_TRIM_US[i] + SERVO_DIR[i] * deg * US_PER_DEG;
  us = constrain(us, 1100.0f, 1900.0f);
  pca.writeMicroseconds(i, (uint16_t)us);
}


void steerInit() {
  pcaOk = i2cProbe(0x40);

  Serial.printf(
    "BOOT,PCA9685,%s\n",
    pcaOk ? "OK" : "FAIL (nothing at 0x40)"
  );

  if (!pcaOk) return;

  Serial.println("PCA,BEGIN");

  if (!pca.begin()) {
    pcaOk = false;
    Serial.println("BOOT,PCA9685,INIT_FAIL");
    return;
  }

  Serial.println("PCA,READY");

  pca.setPWMFreq(50);
  Serial.println("PCA,FREQ_SET");

  for (int i = 0; i < 4; i++) {
    servoWrite(i, 0.0f);
  }

  Serial.println("BOOT,PCA9685,READY");
}


void reinitI2C() {
  homing = false;
  armed = false;
  cmdSpeed = 0.0f;
  setDriverEnable(false);
  sideNow[0] = sideNow[1] = 0.0f;
  driveSide(0, 0.0f);
  driveSide(1, 0.0f);
  pcaOk = false;
  imuOk = false;
  Wire.end();
  delay(50);
  i2cInit();
  delay(100);
  scanI2C();
  steerInit();
  imuInit();
}

void wheelKin(float cx, float cy, int i, float omega, float &angDeg, float &spd) {
  float rx = WX[i] - cx;
  float ry = WY[i] - cy;
  float vx = -omega * ry;
  float vy = omega * rx;
  float mag = sqrtf(vx * vx + vy * vy);
  float a = atan2f(vy, vx);
  float dir = 1.0f;
  if (a > HALF_PI) { a -= PI; dir = -1.0f; }
  else if (a < -HALF_PI) { a += PI; dir = -1.0f; }
  angDeg = a * RAD_TO_DEG;
  spd = dir * mag;
}

void computeTargets(float cmd, float k, float ang[4], float spd[4]) {
  if (fabsf(k) < 0.02f) {
    for (int i = 0; i < 4; i++) { ang[i] = 0.0f; spd[i] = 1.0f; }
  } else {
    float R = 1.0f / k;
    for (int i = 0; i < 4; i++) wheelKin(0.0f, R, i, k, ang[i], spd[i]);
  }
  float m = 0.0f;
  for (int i = 0; i < 4; i++) {
    ang[i] = constrain(ang[i], -MAX_STEER_DEG, MAX_STEER_DEG);
    if (fabsf(spd[i]) > m) m = fabsf(spd[i]);
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

void homingStep(uint32_t now) {
  if (!homing) return;

  uint32_t seq = beaconSequence;
  if (seq != consumedBeaconSequence) {
    consumedBeaconSequence = seq;
    int rssi = latestRssi;
    if (rssi > bestRssi) {
      bestRssi = rssi;
      bestYaw = yawDeg;
    }
  }

  if (blocked && homeState != HOME_BLOCKED && homeState != HOME_ARRIVED) {
    cmdSpeed = 0.0f;
    cmdCurv = 0.0f;
    setHomeState(HOME_BLOCKED);
  }

  if (homeState == HOME_BLOCKED) {
    cmdSpeed = 0.0f;
    cmdCurv = 0.0f;
    if (!blocked && now - homeStateSince > 800) {
      bestRssi = -127;
      sweepStartYaw = yawDeg;
      setHomeState(HOME_SWEEP);
    }
    return;
  }

  if (blocked && homeState == HOME_APPROACH) {
    cmdSpeed = 0.0f;
    cmdCurv = 0.0f;
    setHomeState(HOME_BLOCKED);
    return;
  }

  if (homeState == HOME_SWEEP) {
    cmdSpeed = 0.0f;
    cmdCurv = 0.0f;
    if (fabsf(yawDeg - sweepStartYaw) >= HOMING_SWEEP_DEG) {
      if (bestRssi <= -127 || now - lastBeaconMs > 3000) {
        bestRssi = -127;
        sweepStartYaw = yawDeg;
        Serial.println("HOME,BEACON_NOT_FOUND,RESWEEP");
      } else {
        setHomeState(HOME_TURN);
      }
    }
    return;
  }

  if (homeState == HOME_TURN) {
    cmdSpeed = 0.0f;
    cmdCurv = 0.0f;
    float err = wrap180(bestYaw - yawDeg);
    if (fabsf(err) <= 8.0f) {
      setHomeState(HOME_APPROACH);
      strongRssiSince = 0;
    }
    return;
  }

  if (homeState == HOME_APPROACH) {
    cmdCurv = 0.0f;
    if (now - lastBeaconMs > HOMING_LOST_MS) {
      cmdSpeed = 0.0f;
      bestRssi = -127;
      sweepStartYaw = yawDeg;
      setHomeState(HOME_SWEEP);
      return;
    }
    int rssi = latestRssi;
    if (rssi >= HOMING_TARGET_RSSI) {
      if (strongRssiSince == 0) strongRssiSince = now;
      if (now - strongRssiSince >= 1000) {
        cmdSpeed = 0.0f;
        setHomeState(HOME_ARRIVED);
        Serial.println("HOME,ARRIVED,RSSI_THRESHOLD_ONLY");
        return;
      }
    } else {
      strongRssiSince = 0;
    }
    if (bestRssi > -127 && rssi < bestRssi - HOMING_RESCAN_DROP_DB &&
        now - homeStateSince > 1800) {
      cmdSpeed = 0.0f;
      bestRssi = -127;
      sweepStartYaw = yawDeg;
      setHomeState(HOME_SWEEP);
      return;
    }
    cmdSpeed = HOMING_SPEED;
    return;
  }

  if (homeState == HOME_ARRIVED || homeState == HOME_IDLE) {
    cmdSpeed = 0.0f;
    cmdCurv = 0.0f;
  }
}

void controlStep() {
  bool commandFresh = (millis() - lastCmdMs) <= WATCHDOG_MS;
  bool motorPermit = armed && pcaOk && imuOk && (homing ? bleOk : commandFresh);
  setDriverEnable(motorPermit);

  if (homing && (homeState == HOME_SWEEP || homeState == HOME_TURN)) {
    for (int i = 0; i < 4; i++) {
      float d = constrain(0.0f - steerNow[i], -STEER_STEP_DEG, STEER_STEP_DEG);
      steerNow[i] += d;
      if (pcaOk) servoWrite(i, steerNow[i]);
    }
    bool straightReady = true;
    for (int i = 0; i < 4; i++) if (fabsf(steerNow[i]) > STEER_READY_DEG) straightReady = false;
    float spin = 0.0f;
    if (homeState == HOME_SWEEP) spin = HOMING_TURN_SPEED;
    else {
      float err = wrap180(bestYaw - yawDeg);
      if (fabsf(err) > 8.0f) spin = (err * SPIN_YAW_SIGN >= 0.0f) ? HOMING_TURN_SPEED : -HOMING_TURN_SPEED;
    }
    if (!motorPermit || !straightReady || blocked) spin = 0.0f;
    sideNow[0] = slew(sideNow[0], spin);
    sideNow[1] = slew(sideNow[1], -spin);
    driveSide(0, sideNow[0]);
    driveSide(1, sideNow[1]);
    return;
  }

  float cs = motorPermit ? cmdSpeed : 0.0f;
  if (cs > 0.0f && blocked) cs = 0.0f;
  float ang[4], spd[4];
  computeTargets(cs, cmdCurv, ang, spd);
  if (pcaOk) {
    for (int i = 0; i < 4; i++) {
      float d = constrain(ang[i] - steerNow[i], -STEER_STEP_DEG, STEER_STEP_DEG);
      steerNow[i] += d;
      servoWrite(i, steerNow[i]);
    }
  }
  bool ready = pcaOk;
  for (int i = 0; i < 4 && ready; i++) if (fabsf(ang[i] - steerNow[i]) > STEER_READY_DEG) ready = false;
  float tl = 0.0f, tr = 0.0f;
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
  lastCm = cm;
  if (cm < STOP_CM) { if (nearCount < 3) nearCount++; }
  else if (cm > CLEAR_CM) nearCount = 0;
  blocked = nearCount >= 2;
  if (!humanLog) Serial.printf("U,%.1f,%d\n", cm, blocked ? 1 : 0);
}

void statusStep(uint32_t now) {
  uint32_t age = now - lastBeaconMs;
  bool fresh = beaconHits > 0 && age < 3000;
  if (!humanLog) {
    if (fresh) Serial.printf("B,%d\n", (int)latestRssi);
    return;
  }
  char rs[32];
  if (fresh) snprintf(rs, sizeof(rs), "%d dBm (%lu ms ago)", (int)latestRssi, (unsigned long)age);
  else snprintf(rs, sizeof(rs), "no beacon");
  char ds[16];
  if (lastCm >= 900.0f) snprintf(ds, sizeof(ds), "none");
  else snprintf(ds, sizeof(ds), "%.1f cm", lastCm);
  Serial.printf("RSSI %-22s | ADV %lu HIT %lu | YAW %7.1f | DIST %-8s | BLK %d | %-8s | PCA %s MPU %s BLE %s | ARM %d\n",
                rs, (unsigned long)advSeen, (unsigned long)beaconHits, yawDeg, ds, blocked ? 1 : 0,
                homeStateName(homeState), pcaOk ? "ok" : "--", imuOk ? "ok" : "--", bleOk ? "ok" : "--",
                armed ? 1 : 0);
}

void handleLine(char *line) {
  if (line[0] == 'H') {
    int h;
    if (sscanf(line, "H,%d", &h) == 1) { if (h == 1) startHoming(); else stopHoming(); }
  } else if (line[0] == 'C') {
    homing = false;
    homeState = HOME_IDLE;
    int mode;
    float s, k;
    if (sscanf(line, "C,%d,%f,%f", &mode, &s, &k) == 3) {
      cmdSpeed = constrain(s, -1.0f, 1.0f);
      cmdCurv = constrain(k, -KMAX, KMAX);
      lastCmdMs = millis();
    }
  } else if (line[0] == 'S') {
    homing = false;
    homeState = HOME_IDLE;
    cmdSpeed = 0.0f;
    lastCmdMs = millis();
  } else if (line[0] == 'A') {
    homing = false;
    homeState = HOME_IDLE;
    int a;
    if (sscanf(line, "A,%d", &a) == 1) {
      armed = (a == 1) && pcaOk && imuOk;
      cmdSpeed = 0.0f;
      setDriverEnable(false);
      lastCmdMs = millis();
      Serial.printf("STATUS,ARMED,%d\n", armed ? 1 : 0);
    }
  } else if (line[0] == 'I') {
    scanI2C();
  } else if (line[0] == 'R') {
    reinitI2C();
  } else if (line[0] == 'L') {
    int v;
    if (sscanf(line, "L,%d", &v) == 1) humanLog = (v != 0);
  }
}

void pollSerial() {
  static char buf[64];
  static int n = 0;
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (n > 0) { buf[n] = 0; handleLine(buf); }
      n = 0;
    } else if (n < (int)sizeof(buf) - 1) buf[n++] = c;
  }
}

void setup() {
  Serial.begin(115200);
  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 3000) delay(10);
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
  i2cInit();
  delay(200);
  scanI2C();
  steerInit();
  imuInit();
  bleInit();
  Serial.println("BOOT,MOTOR,READY");
  Serial.println("CMDS: A,1 | A,0 | C,0,speed,curv | S | H,1 | H,0 | I (scan i2c) | R (reinit i2c) | L,0 or L,1 (log mode)");
}

void loop() {
  uint32_t now = millis();
  pollSerial();
  homingStep(now);
  bleWatchdog(now);
  if (now - lastControl >= CONTROL_PERIOD_MS) { lastControl = now; controlStep(); }
  if (now - lastSonar >= SONAR_PERIOD_MS) { lastSonar = now; sonarStep(); }
  if (now - lastImu >= IMU_PERIOD_MS) { lastImu = now; imuStep(now); }
  if (now - lastStatus >= STATUS_PERIOD_MS) { lastStatus = now; statusStep(now); }
  if (!humanLog && homing && now - lastHomeTelemetry >= 500) {
    lastHomeTelemetry = now;
    Serial.printf("HOME,DATA,%s,%d,%.1f\n", homeStateName(homeState), (int)latestRssi, yawDeg);
  }
}
