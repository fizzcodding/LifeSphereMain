#pragma once
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "secrets.h"

#ifndef FB_WIFI_SSID
#error "secrets.h must define FB_WIFI_SSID. Copy secrets.h.example to secrets.h and fill in your values."
#endif

#ifndef VITAL32_TLS_INSECURE
#define VITAL32_TLS_INSECURE 0
#endif

#if VITAL32_TLS_INSECURE != 1
#if VITAL32_TLS_INSECURE == 0
#endif
#endif

#define FB_CONNECT_TIMEOUT_MS 10000
#define FB_RECONNECT_INTERVAL_MS 30000
#define FB_HTTP_TIMEOUT_MS 5000
#define FB_TOKEN_TTL_MS 3540000UL

static unsigned long _fbLastReconnectAttempt = 0;
static bool _fbConnected = false;

static char _fbIdToken[1200] = {0};
static char _fbRefreshToken[512] = {0};
static char _fbUid[64] = {0};
static unsigned long _fbTokenExpiry = 0;

static void fbWifiInit() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(FB_WIFI_SSID, FB_WIFI_PASSWORD);
}

static void fbWifiTick() {
  if (WiFi.status() == WL_CONNECTED) {
    _fbConnected = true;
    return;
  }
  _fbConnected = false;
  unsigned long now = millis();
  if (now - _fbLastReconnectAttempt >= FB_RECONNECT_INTERVAL_MS) {
    _fbLastReconnectAttempt = now;
    WiFi.disconnect(false);
    WiFi.begin(FB_WIFI_SSID, FB_WIFI_PASSWORD);
  }
}

static bool fbEnsureConnected() {
  if (WiFi.status() == WL_CONNECTED) {
    _fbConnected = true;
    return true;
  }
  fbWifiTick();
  return false;
}

static String _fbStripTrailingSlash(const char* url) {
  String s(url);
  if (s.length() > 0 && s[s.length() - 1] == '/') {
    s.remove(s.length() - 1);
  }
  return s;
}

static String _fbNodeUrl(const char* path) {
  String base = _fbStripTrailingSlash(FB_DATABASE_URL);
  return base + "/users/" + _fbUid + "/vital32/" + path + ".json?auth=" + _fbIdToken;
}

static bool _fbSignIn() {
  WiFiClientSecure client;
#if VITAL32_TLS_INSECURE == 1
  client.setInsecure();
#endif
  HTTPClient http;
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") + FB_WEB_API_KEY;
  if (!http.begin(client, url)) return false;
  http.setTimeout(FB_HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  JsonDocument req;
  req["email"] = FB_DEVICE_EMAIL;
  req["password"] = FB_DEVICE_PASSWORD;
  req["returnSecureToken"] = true;
  String body;
  serializeJson(req, body);
  int code = http.POST(body);
  if (code != 200) { http.end(); return false; }
  String resp = http.getString();
  http.end();
  JsonDocument doc;
  if (deserializeJson(doc, resp) != DeserializationError::Ok) return false;
  const char* tok = doc["idToken"];
  const char* ref = doc["refreshToken"];
  const char* uid = doc["localId"];
  if (!tok || !ref || !uid) return false;
  strncpy(_fbIdToken, tok, sizeof(_fbIdToken) - 1);
  strncpy(_fbRefreshToken, ref, sizeof(_fbRefreshToken) - 1);
  strncpy(_fbUid, uid, sizeof(_fbUid) - 1);
  _fbTokenExpiry = millis() + FB_TOKEN_TTL_MS;
  return true;
}

static bool _fbRefreshAuth() {
  if (_fbRefreshToken[0] == '\0') return _fbSignIn();
  WiFiClientSecure client;
#if VITAL32_TLS_INSECURE == 1
  client.setInsecure();
#endif
  HTTPClient http;
  String url = String("https://securetoken.googleapis.com/v1/token?key=") + FB_WEB_API_KEY;
  if (!http.begin(client, url)) return false;
  http.setTimeout(FB_HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  String body = String("grant_type=refresh_token&refresh_token=") + _fbRefreshToken;
  int code = http.POST(body);
  if (code != 200) { http.end(); return _fbSignIn(); }
  String resp = http.getString();
  http.end();
  JsonDocument doc;
  if (deserializeJson(doc, resp) != DeserializationError::Ok) return _fbSignIn();
  const char* tok = doc["id_token"];
  const char* ref = doc["refresh_token"];
  if (!tok || !ref) return _fbSignIn();
  strncpy(_fbIdToken, tok, sizeof(_fbIdToken) - 1);
  strncpy(_fbRefreshToken, ref, sizeof(_fbRefreshToken) - 1);
  _fbTokenExpiry = millis() + FB_TOKEN_TTL_MS;
  return true;
}

static bool _fbEnsureToken() {
  if (_fbIdToken[0] == '\0') return _fbSignIn();
  if (millis() > _fbTokenExpiry) return _fbRefreshAuth();
  return true;
}

static bool _fbHttpPatch(const String& url, const String& body) {
  WiFiClientSecure client;
#if VITAL32_TLS_INSECURE == 1
  client.setInsecure();
#endif
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.setTimeout(FB_HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  int code = http.PATCH(body);
  http.end();
  if (code == 401 || code == 403) {
    if (!_fbRefreshAuth()) return false;
    String newUrl = url;
    int authPos = newUrl.indexOf("?auth=");
    if (authPos >= 0) newUrl = newUrl.substring(0, authPos) + "?auth=" + _fbIdToken;
    WiFiClientSecure client2;
#if VITAL32_TLS_INSECURE == 1
    client2.setInsecure();
#endif
    HTTPClient http2;
    if (!http2.begin(client2, newUrl)) return false;
    http2.setTimeout(FB_HTTP_TIMEOUT_MS);
    http2.addHeader("Content-Type", "application/json");
    int code2 = http2.PATCH(body);
    http2.end();
    return code2 >= 200 && code2 < 300;
  }
  return code >= 200 && code < 300;
}

static bool _fbHttpPut(const String& url, const String& body) {
  WiFiClientSecure client;
#if VITAL32_TLS_INSECURE == 1
  client.setInsecure();
#endif
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.setTimeout(FB_HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  int code = http.PUT(body);
  http.end();
  if (code == 401 || code == 403) {
    if (!_fbRefreshAuth()) return false;
    String newUrl = url;
    int authPos = newUrl.indexOf("?auth=");
    if (authPos >= 0) newUrl = newUrl.substring(0, authPos) + "?auth=" + _fbIdToken;
    WiFiClientSecure client2;
#if VITAL32_TLS_INSECURE == 1
    client2.setInsecure();
#endif
    HTTPClient http2;
    if (!http2.begin(client2, newUrl)) return false;
    http2.setTimeout(FB_HTTP_TIMEOUT_MS);
    http2.addHeader("Content-Type", "application/json");
    int code2 = http2.PUT(body);
    http2.end();
    return code2 >= 200 && code2 < 300;
  }
  return code >= 200 && code < 300;
}

struct Vital32Payload {
  float hr, spo2, temp;
  int steps;
  float gsr;
  bool gsr_verified;
  float accel_x, accel_y, accel_z;
  float gyro_x, gyro_y, gyro_z;
  float pressure, humidity, gas_resistance, altitude, uv_index;
  bool fall_detected, ecg_leads_on;
  unsigned long timestamp_ms;
  float temp_trend_rate;
  float temp_cusum;
  bool temp_trend_alert;
  bool temp_baseline_ready;
};

static bool fbWriteVitals(const Vital32Payload& p) {
  if (!fbEnsureConnected()) return false;
  if (!_fbEnsureToken()) return false;
  JsonDocument doc;
  doc["hr"]["currently"] = (int)p.hr;
  doc["spo2"]["currently"] = (int)p.spo2;
  doc["temp"]["currently"] = roundf(p.temp * 10.0f) / 10.0f;
  doc["steps"]["currently"] = p.steps;
  JsonObject raw = doc["raw"].to<JsonObject>();
  raw["accel_x"] = p.accel_x;
  raw["accel_y"] = p.accel_y;
  raw["accel_z"] = p.accel_z;
  raw["gyro_x"] = p.gyro_x;
  raw["gyro_y"] = p.gyro_y;
  raw["gyro_z"] = p.gyro_z;
  raw["pressure_hpa"] = p.pressure;
  raw["humidity_pct"] = p.humidity;
  raw["gas_resistance_ohm"] = p.gas_resistance;
  raw["altitude_m"] = p.altitude;
  raw["uv_adc_raw"] = p.uv_index;
  doc["gsr"]["currently"] = p.gsr;
  doc["gsr"]["verified"] = p.gsr_verified;
  JsonObject status = doc["status"].to<JsonObject>();
  status["fall_detected"] = p.fall_detected;
  status["ecg_leads_on"] = p.ecg_leads_on;
  status["ts_ms"] = p.timestamp_ms;
  status["temp_trend_rate_c_per_hour"] = p.temp_trend_rate;
  status["temp_trend_cusum"] = p.temp_cusum;
  status["temp_trend_alert"] = p.temp_trend_alert;
  status["temp_baseline_ready"] = p.temp_baseline_ready;
  status["temp_trend_note"] = "Experimental surface-temperature trend; not a fever diagnosis";
  status["spo2_valid"] = false;
  status["spo2_note"] = "Not calculated: calibration required";
  String body;
  serializeJson(doc, body);
  String base = _fbStripTrailingSlash(FB_DATABASE_URL);
  String url = base + "/users/" + _fbUid + "/vital32.json?auth=" + _fbIdToken;
  return _fbHttpPatch(url, body);
}

static bool fbWriteFallEvent(float accel_peak_g, unsigned long ts_ms) {
  if (!fbEnsureConnected()) return false;
  if (!_fbEnsureToken()) return false;
  JsonDocument doc;
  doc["ts_ms"] = ts_ms;
  doc["accel_peak_g"] = accel_peak_g;
  doc["confirmed"] = true;
  String body;
  serializeJson(doc, body);
  String url = _fbNodeUrl("events/fall");
  return _fbHttpPut(url, body);
}

static bool fbIsConnected() { return WiFi.status() == WL_CONNECTED; }
