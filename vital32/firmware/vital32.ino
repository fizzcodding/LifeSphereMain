#include <Wire.h>
#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_MLX90614.h>
#include <MAX30105.h>
#include <heartRate.h>
#include <Adafruit_BME680.h>
#include <ArduinoJson.h>

#include "firebase_writter.h"
#include "fall_detection.h"
#include "hrv.h"

#define PIN_AD8232_OUT  32
#define PIN_AD8232_LOM  33
#define PIN_AD8232_LOP  25
#define PIN_UV          36
#define PIN_POT         34
#define PIN_GSR_SCK     14
#define PIN_GSR_MISO     4
#define PIN_GSR_CS      27

#define I2C_A_SDA       21
#define I2C_A_SCL       22
#define I2C_B_SDA       19
#define I2C_B_SCL       18

#define OLED_ADDR       0x3C
#define OLED_WIDTH      128
#define OLED_HEIGHT      64

#define SCHED_ACCEL_MS      20
#define SCHED_PPG_MS      1000
#define SCHED_TEMP_MS     1000
#define SCHED_GSR_MS      1000
#define SCHED_ENV_MS      5000
#define SCHED_FIREBASE_MS 5000
#define SCHED_OLED_MS      500

#define ADC_SAMPLES        32
#define UV_VOLTAGE_MV_PER_STEP  0.806f
#define UV_SENSITIVITY_MVPERUVIDX 0.1f

Adafruit_SSD1306 oled(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
Adafruit_MPU6050 mpu;
Adafruit_MLX90614 mlx;
MAX30105 max30102;
Adafruit_BME680 bme(&Wire1);

FallDetector fallDet;
StepCounter stepCnt;

struct SensorState {
    float ax, ay, az;
    float gx, gy, gz;
    float hr_bpm;
    float spo2_pct;
    float skin_temp_c;
    float pressure_hpa;
    float humidity_pct;
    float gas_resistance_ohm;
    float altitude_m;
    float gsr_raw;
    float uv_index;
    bool ecg_leads_on;
    bool fall_active;
    bool gsr_verified;
};

static SensorState gSensors = {};

static unsigned long tAccel    = 0;
static unsigned long tPpg      = 0;
static unsigned long tTemp     = 0;
static unsigned long tGsr      = 0;
static unsigned long tEnv      = 0;
static unsigned long tFirebase = 0;
static unsigned long tOled     = 0;

static bool bMpuOk    = false;
static bool bMaxOk    = false;
static bool bMlxOk    = false;
static bool bBmeOk    = false;

static byte maxRateBuffer[4];
static byte maxRateIdx = 0;
static long maxLastBeat = 0;
static float maxBeatsPerMinute = 0;
static int maxBeatAvg = 0;

static uint8_t oledPage = 0;
static int oledHr = -1;
static int oledSpo2 = -1;
static float oledTemp = -1.0f;
static int oledSteps = -1;
static bool oledFall = false;

static SPIClass gsrSpi(VSPI);

static void initOled() {
    oled.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR);
    oled.clearDisplay();
    oled.setTextColor(SSD1306_WHITE);
    oled.setTextSize(1);
    oled.setCursor(0, 0);
    oled.println("Vital32");
    oled.println("Starting...");
    oled.display();
}

static void initBusA() {
    Wire.begin(I2C_A_SDA, I2C_A_SCL);
    Wire.setClock(400000);
}

static void initBusB() {
    Wire1.begin(I2C_B_SDA, I2C_B_SCL);
    Wire1.setClock(400000);
}

static void initMpu() {
    if (mpu.begin(0x68, &Wire)) {
        mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
        mpu.setGyroRange(MPU6050_RANGE_500_DEG);
        mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
        bMpuOk = true;
    }
}

static void initMax30102() {
    if (max30102.begin(Wire1, I2C_SPEED_FAST)) {
        max30102.setup();
        max30102.setPulseAmplitudeRed(0x0A);
        max30102.setPulseAmplitudeGreen(0);
        bMaxOk = true;
    }
}

static void initMlx() {
    if (mlx.begin(0x5A, &Wire1)) {
        bMlxOk = true;
    }
}

static void initBme() {
    if (bme.begin(0x77)) {
        bme.setTemperatureOversampling(BME680_OS_8X);
        bme.setHumidityOversampling(BME680_OS_2X);
        bme.setPressureOversampling(BME680_OS_4X);
        bme.setIIRFilterSize(BME680_FILTER_SIZE_3);
        bme.setGasHeater(320, 150);
        bBmeOk = true;
    }
}

static void initGsr() {
    gsrSpi.begin(PIN_GSR_SCK, PIN_GSR_MISO, -1, PIN_GSR_CS);
    pinMode(PIN_GSR_CS, OUTPUT);
    digitalWrite(PIN_GSR_CS, HIGH);
}

static void initAnalog() {
    pinMode(PIN_AD8232_LOM, INPUT);
    pinMode(PIN_AD8232_LOP, INPUT);
    analogReadResolution(12);
    analogSetAttenuation(ADC_11db);
}

static void readAccel() {
    if (!bMpuOk) return;
    sensors_event_t a, g, temp;
    if (!mpu.getEvent(&a, &g, &temp)) return;

    gSensors.ax = a.acceleration.x / 9.80665f;
    gSensors.ay = a.acceleration.y / 9.80665f;
    gSensors.az = a.acceleration.z / 9.80665f;
    gSensors.gx = g.gyro.x;
    gSensors.gy = g.gyro.y;
    gSensors.gz = g.gyro.z;

    unsigned long now = millis();
    stepUpdate(stepCnt, gSensors.ax, gSensors.ay, gSensors.az, now);

    bool fell = fallUpdate(fallDet, gSensors.ax, gSensors.ay, gSensors.az, now);
    if (fell) {
        gSensors.fall_active = true;
        fbWriteFallEvent(fallDet.impact_peak_g, now);
        fallDet.fall_event_pending = false;
    }
    if (fallDet.state == FallState::IDLE && !fallDet.fall_event_pending) {
        gSensors.fall_active = (fallDet.state != FallState::IDLE);
    }
}

static void readPpg() {
    if (!bMaxOk) return;

    long irSample = 0;
    for (int i = 0; i < 8; i++) {
        max30102.check();
        if (max30102.available()) {
            irSample = max30102.getIR();
            max30102.nextSample();
        }
        delay(10);
    }

    if (irSample < 50000) {
        gSensors.hr_bpm = 0;
        gSensors.spo2_pct = 0;
        return;
    }

    if (checkForBeat(irSample)) {
        long delta = millis() - maxLastBeat;
        maxLastBeat = millis();
        maxBeatsPerMinute = 60.0f / (delta / 1000.0f);
        if (maxBeatsPerMinute > 30 && maxBeatsPerMinute < 200) {
            maxRateBuffer[maxRateIdx++] = (byte)maxBeatsPerMinute;
            maxRateIdx %= 4;
            int total = 0;
            for (int i = 0; i < 4; i++) total += maxRateBuffer[i];
            maxBeatAvg = total / 4;
        }
    }

    if (maxBeatAvg > 0) {
        gSensors.hr_bpm = (float)maxBeatAvg;
    }

    long redSample = 0;
    max30102.check();
    if (max30102.available()) {
        redSample = max30102.getRed();
        max30102.nextSample();
    }

    if (irSample > 50000 && redSample > 10000) {
        float ratio = (float)redSample / (float)irSample;
        float spo2 = 110.0f - 25.0f * ratio;
        spo2 = constrain(spo2, 70.0f, 100.0f);
        gSensors.spo2_pct = spo2;
    }
}

static void readTemp() {
    if (!bMlxOk) return;
    float t = mlx.readObjectTempC();
    if (!isnan(t) && t > 20.0f && t < 45.0f) {
        gSensors.skin_temp_c = t;
    }
}

static void readGsr() {
    float sum = 0;
    int valid = 0;
    digitalWrite(PIN_GSR_CS, LOW);
    delayMicroseconds(5);
    for (int i = 0; i < ADC_SAMPLES; i++) {
        uint8_t hi = gsrSpi.transfer(0x00);
        uint8_t lo = gsrSpi.transfer(0x00);
        uint16_t raw = ((uint16_t)hi << 8) | lo;
        raw &= 0x0FFF;
        sum += raw;
        valid++;
    }
    digitalWrite(PIN_GSR_CS, HIGH);

    if (valid > 0) {
        gSensors.gsr_raw = sum / valid;
    }
    gSensors.gsr_verified = false;
}

static void readEnv() {
    if (!bBmeOk) return;
    if (!bme.performReading()) return;
    gSensors.pressure_hpa = bme.pressure / 100.0f;
    gSensors.humidity_pct = bme.humidity;
    gSensors.gas_resistance_ohm = bme.gas_resistance;
    gSensors.altitude_m = bme.readAltitude(1013.25f);

    int raw_uv = 0;
    for (int i = 0; i < 16; i++) {
        raw_uv += analogRead(PIN_UV);
        delayMicroseconds(100);
    }
    raw_uv /= 16;
    float voltage_mv = raw_uv * UV_VOLTAGE_MV_PER_STEP;
    gSensors.uv_index = voltage_mv / 200.0f;
    gSensors.uv_index = constrain(gSensors.uv_index, 0.0f, 15.0f);
}

static bool ecgLeadsOn() {
    return (digitalRead(PIN_AD8232_LOM) == LOW && digitalRead(PIN_AD8232_LOP) == LOW);
}

static void pushFirebase() {
    gSensors.ecg_leads_on = ecgLeadsOn();

    Vital32Payload p;
    p.hr           = gSensors.hr_bpm;
    p.spo2         = gSensors.spo2_pct;
    p.temp         = gSensors.skin_temp_c;
    p.steps        = stepGet(stepCnt);
    p.gsr          = gSensors.gsr_raw;
    p.gsr_verified = false;
    p.accel_x      = gSensors.ax;
    p.accel_y      = gSensors.ay;
    p.accel_z      = gSensors.az;
    p.gyro_x       = gSensors.gx;
    p.gyro_y       = gSensors.gy;
    p.gyro_z       = gSensors.gz;
    p.pressure     = gSensors.pressure_hpa;
    p.humidity     = gSensors.humidity_pct;
    p.gas_resistance = gSensors.gas_resistance_ohm;
    p.altitude     = gSensors.altitude_m;
    p.uv_index     = gSensors.uv_index;
    p.fall_detected = gSensors.fall_active;
    p.ecg_leads_on  = gSensors.ecg_leads_on;
    p.timestamp_ms  = millis();

    fbWriteVitals(p);
}

static void updateOled() {
    int newHr    = (int)gSensors.hr_bpm;
    int newSpo2  = (int)gSensors.spo2_pct;
    float newTemp = gSensors.skin_temp_c;
    int newSteps = stepGet(stepCnt);
    bool newFall = gSensors.fall_active;

    bool changed = (newHr != oledHr || newSpo2 != oledSpo2
        || fabsf(newTemp - oledTemp) > 0.1f
        || newSteps != oledSteps
        || newFall != oledFall);

    if (!changed) return;

    oledHr = newHr; oledSpo2 = newSpo2;
    oledTemp = newTemp; oledSteps = newSteps;
    oledFall = newFall;

    oled.clearDisplay();
    oled.setTextSize(1);

    if (oledFall) {
        oled.setTextSize(2);
        oled.setCursor(0, 16);
        oled.println("!! FALL !!");
        oled.setTextSize(1);
        oled.display();
        return;
    }

    oled.setCursor(0, 0);
    oled.print("HR:"); oled.print(oledHr);   oled.print(" BPM");
    oled.setCursor(0, 12);
    oled.print("SpO2:"); oled.print(oledSpo2); oled.print("%");
    oled.setCursor(0, 24);
    oled.print("Temp:"); oled.print(oledTemp, 1); oled.print("C");
    oled.setCursor(0, 36);
    oled.print("Steps:"); oled.print(oledSteps);

    oled.setCursor(0, 50);
    bool leadsOn = ecgLeadsOn();
    if (leadsOn) {
        oled.print("ECG:OK ");
    } else {
        oled.print("ECG:OFF");
    }

    if (!fbIsConnected()) {
        oled.setCursor(72, 50);
        oled.print("NoWiFi");
    }

    oled.display();
}

void setup() {
    Serial.begin(115200);
    initBusA();
    initBusB();
    initOled();
    initMpu();
    initMax30102();
    initMlx();
    initBme();
    initGsr();
    initAnalog();
    fbWifiInit();

    oled.clearDisplay();
    oled.setCursor(0, 0);
    oled.println("Vital32 Ready");
    oled.print("WiFi:");
    oled.println(fbIsConnected() ? "OK" : "FAIL");
    oled.print("MPU:");  oled.println(bMpuOk  ? "OK" : "FAIL");
    oled.print("MAX:");  oled.println(bMaxOk  ? "OK" : "FAIL");
    oled.print("MLX:");  oled.println(bMlxOk  ? "OK" : "FAIL");
    oled.print("BME:");  oled.println(bBmeOk  ? "OK" : "FAIL");
    oled.display();
    delay(2000);
}

void loop() {
    unsigned long now = millis();

    if (now - tAccel >= SCHED_ACCEL_MS) {
        tAccel = now;
        readAccel();
    }

    if (now - tPpg >= SCHED_PPG_MS) {
        tPpg = now;
        readPpg();
    }

    if (now - tTemp >= SCHED_TEMP_MS) {
        tTemp = now;
        readTemp();
    }

    if (now - tGsr >= SCHED_GSR_MS) {
        tGsr = now;
        readGsr();
    }

    if (now - tEnv >= SCHED_ENV_MS) {
        tEnv = now;
        readEnv();
    }

    if (now - tFirebase >= SCHED_FIREBASE_MS) {
        tFirebase = now;
        pushFirebase();
    }

    if (now - tOled >= SCHED_OLED_MS) {
        tOled = now;
        updateOled();
    }
}
