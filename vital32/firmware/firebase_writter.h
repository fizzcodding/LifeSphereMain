#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

#define FB_WIFI_SSID      "YOUR_WIFI_SSID"
#define FB_WIFI_PASSWORD  "YOUR_WIFI_PASSWORD"
#define FB_DATABASE_URL   "https://hollow-core-default-rtdb.firebaseio.com"
#define FB_AUTH_TOKEN     "YOUR_FIREBASE_DATABASE_SECRET_OR_AUTH_TOKEN"
#define FB_USER_UID       "YOUR_FIREBASE_USER_UID"

#define FB_CONNECT_TIMEOUT_MS    10000
#define FB_RECONNECT_INTERVAL_MS 30000
#define FB_HTTP_TIMEOUT_MS        5000

static unsigned long _fbLastReconnectAttempt = 0;
static bool _fbConnected = false;

static void fbWifiInit() {
    WiFi.mode(WIFI_STA);
    WiFi.begin(FB_WIFI_SSID, FB_WIFI_PASSWORD);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < FB_CONNECT_TIMEOUT_MS) {
        delay(200);
    }
    _fbConnected = (WiFi.status() == WL_CONNECTED);
}

static bool fbEnsureConnected() {
    if (WiFi.status() == WL_CONNECTED) {
        _fbConnected = true;
        return true;
    }
    unsigned long now = millis();
    if (now - _fbLastReconnectAttempt < FB_RECONNECT_INTERVAL_MS) {
        return false;
    }
    _fbLastReconnectAttempt = now;
    WiFi.disconnect(false);
    WiFi.begin(FB_WIFI_SSID, FB_WIFI_PASSWORD);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < FB_CONNECT_TIMEOUT_MS) {
        delay(100);
    }
    _fbConnected = (WiFi.status() == WL_CONNECTED);
    return _fbConnected;
}

static bool _fbHttpPatch(const String& url, const String& body) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    if (!http.begin(client, url)) return false;
    http.setTimeout(FB_HTTP_TIMEOUT_MS);
    http.addHeader("Content-Type", "application/json");
    int code = http.PATCH(body);
    http.end();
    return (code == 200);
}

static bool _fbHttpPut(const String& url, const String& body) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    if (!http.begin(client, url)) return false;
    http.setTimeout(FB_HTTP_TIMEOUT_MS);
    http.addHeader("Content-Type", "application/json");
    int code = http.PUT(body);
    http.end();
    return (code == 200);
}

static String _fbNodeUrl(const char* path) {
    return String(FB_DATABASE_URL)
        + "/users/" + FB_USER_UID
        + "/vital32/" + path
        + ".json?auth=" + FB_AUTH_TOKEN;
}

static bool fbPatchFloat(const char* key, float value) {
    if (!fbEnsureConnected()) return false;
    JsonDocument doc;
    doc["currently"] = value;
    String body;
    serializeJson(doc, body);
    return _fbHttpPatch(_fbNodeUrl(key), body);
}

static bool fbPatchInt(const char* key, int value) {
    if (!fbEnsureConnected()) return false;
    JsonDocument doc;
    doc["currently"] = value;
    String body;
    serializeJson(doc, body);
    return _fbHttpPatch(_fbNodeUrl(key), body);
}

struct Vital32Payload {
    float hr;
    float spo2;
    float temp;
    int steps;
    float gsr;
    bool gsr_verified;
    float accel_x;
    float accel_y;
    float accel_z;
    float gyro_x;
    float gyro_y;
    float gyro_z;
    float pressure;
    float humidity;
    float gas_resistance;
    float altitude;
    float uv_index;
    bool fall_detected;
    bool ecg_leads_on;
    unsigned long timestamp_ms;
};

static bool fbWriteVitals(const Vital32Payload& p) {
    if (!fbEnsureConnected()) return false;

    JsonDocument doc;

    doc["hr"]["currently"]   = (int)p.hr;
    doc["spo2"]["currently"] = (int)p.spo2;
    doc["temp"]["currently"] = roundf(p.temp * 10.0f) / 10.0f;
    doc["steps"]["currently"] = p.steps;

    JsonObject raw = doc["raw"].to<JsonObject>();
    raw["accel_x"]             = p.accel_x;
    raw["accel_y"]             = p.accel_y;
    raw["accel_z"]             = p.accel_z;
    raw["gyro_x"]              = p.gyro_x;
    raw["gyro_y"]              = p.gyro_y;
    raw["gyro_z"]              = p.gyro_z;
    raw["pressure_hpa"]        = p.pressure;
    raw["humidity_pct"]        = p.humidity;
    raw["gas_resistance_ohm"]  = p.gas_resistance;
    raw["altitude_m"]          = p.altitude;
    raw["uv_index"]            = p.uv_index;

    doc["gsr"]["currently"] = p.gsr;
    doc["gsr"]["verified"]  = p.gsr_verified;

    JsonObject status = doc["status"].to<JsonObject>();
    status["fall_detected"] = p.fall_detected;
    status["ecg_leads_on"]  = p.ecg_leads_on;
    status["ts_ms"]         = (unsigned long)p.timestamp_ms;

    String body;
    serializeJson(doc, body);

    String url = String(FB_DATABASE_URL)
        + "/users/" + FB_USER_UID
        + "/vital32.json?auth=" + FB_AUTH_TOKEN;

    return _fbHttpPatch(url, body);
}

static bool fbWriteFallEvent(float accel_peak_g, unsigned long ts_ms) {
    if (!fbEnsureConnected()) return false;

    JsonDocument doc;
    doc["ts_ms"]       = (unsigned long)ts_ms;
    doc["accel_peak_g"] = accel_peak_g;
    doc["confirmed"]   = true;

    String body;
    serializeJson(doc, body);

    String url = String(FB_DATABASE_URL)
        + "/users/" + FB_USER_UID
        + "/vital32/events/fall.json?auth=" + FB_AUTH_TOKEN;

    return _fbHttpPut(url, body);
}

static bool fbIsConnected() {
    return WiFi.status() == WL_CONNECTED;
}
