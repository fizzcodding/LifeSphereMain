#pragma once
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "secrets.h"

// Prototype REST writer. For production, provide the Firebase root CA and use
// client.setCACert(rootCA). Insecure TLS is disabled by default.
struct Vital32Payload {
  bool hr_valid = false; float hr = 0;
  bool spo2_valid = false;
  float temp = 0, steps = 0, gsr = 0; bool gsr_verified = false;
  float accel_x = 0, accel_y = 0, accel_z = 0, gyro_x = 0, gyro_y = 0, gyro_z = 0;
  float pressure = 0, humidity = 0, gas_resistance = 0, altitude = 0, uv_index = 0;
  bool fall_detected = false, ecg_leads_on = false;
  uint32_t timestamp_ms = 0;
  float temp_trend_rate = 0, temp_cusum = 0;
  bool temp_trend_alert = false, temp_baseline_ready = false;
  float hrv_rmssd_ms = 0, hrv_sdnn_ms = 0; bool hrv_valid = false;
};
inline bool fbIsConnected() { return WiFi.status() == WL_CONNECTED; }
inline void fbWifiTick() {
  static uint32_t lastAttempt = 0;
  if (WiFi.status() != WL_CONNECTED && millis() - lastAttempt > 15000) {
    lastAttempt = millis(); WiFi.begin(FB_WIFI_SSID, FB_WIFI_PASSWORD);
  }
}
inline String fbUrl(const String &path) {
  String u = String(FB_DATABASE_URL); while (u.endsWith("/")) u.remove(u.length()-1);
  u += path + ".json";
  if (String(FB_AUTH_TOKEN).length()) u += "?auth=" + String(FB_AUTH_TOKEN);
  return u;
}
inline bool fbPutJson(const String &path, const String &json) {
  if (!fbIsConnected()) return false;
  WiFiClientSecure client;
#if defined(FB_ALLOW_INSECURE_TLS) && FB_ALLOW_INSECURE_TLS
  client.setInsecure(); // prototype-only: vulnerable to man-in-the-middle attacks
#else
  Serial.println(F("FIREBASE,SKIPPED,TLS CA not configured (fail-closed)"));
  return false;
#endif
  HTTPClient http;
  if (!http.begin(client, fbUrl(path))) return false;
  http.addHeader("Content-Type", "application/json");
  int code = http.PUT(json);
  http.end();
  Serial.printf("FIREBASE,HTTP,%d\n", code);
  return code >= 200 && code < 300;
}
inline void fbWriteVitals(const Vital32Payload &p) {
  String j = "{";
  j += "\"hr_valid\":" + String(p.hr_valid ? "true" : "false");
  j += ",\"hr_bpm\":" + String(p.hr, 2);
  j += ",\"spo2_valid\":" + String(p.spo2_valid ? "true" : "false");
  j += ",\"object_temp_c\":" + String(p.temp, 2);
  j += ",\"steps\":" + String((uint32_t)p.steps);
  j += ",\"gsr_raw\":" + String(p.gsr, 1) + ",\"gsr_calibrated\":false";
  j += ",\"accel_x_g\":" + String(p.accel_x, 3) + ",\"accel_y_g\":" + String(p.accel_y, 3) + ",\"accel_z_g\":" + String(p.accel_z, 3);
  j += ",\"gyro_x\":" + String(p.gyro_x, 4) + ",\"gyro_y\":" + String(p.gyro_y, 4) + ",\"gyro_z\":" + String(p.gyro_z, 4);
  j += ",\"pressure_hpa\":" + String(p.pressure, 2) + ",\"humidity_pct\":" + String(p.humidity, 2);
  j += ",\"gas_resistance_ohm\":" + String(p.gas_resistance, 1) + ",\"altitude_m\":" + String(p.altitude, 2) + ",\"uv_raw_adc\":" + String(p.uv_index, 1);
  j += ",\"fall_active\":" + String(p.fall_detected ? "true" : "false") + ",\"ecg_leads_on\":" + String(p.ecg_leads_on ? "true" : "false");
  j += ",\"timestamp_ms\":" + String(p.timestamp_ms);
  j += ",\"temperature_trend_c_per_hour\":" + String(p.temp_trend_rate, 3) + ",\"temperature_cusum\":" + String(p.temp_cusum, 3);
  j += ",\"temperature_trend_alert\":" + String(p.temp_trend_alert ? "true" : "false") + ",\"temperature_baseline_ready\":" + String(p.temp_baseline_ready ? "true" : "false");
  j += ",\"hrv_valid\":" + String(p.hrv_valid ? "true" : "false") + ",\"hrv_rmssd_ms\":" + String(p.hrv_rmssd_ms, 2) + ",\"hrv_sdnn_ms\":" + String(p.hrv_sdnn_ms, 2) + "}";
  fbPutJson(String("/users/") + FB_USER_UID + "/vital32/latest", j);
}
inline void fbWriteFallEvent(float peakG, unsigned long timestampMs) {
  String j = "{\"impact_peak_g\":" + String(peakG, 2) + ",\"timestamp_ms\":" + String(timestampMs) + ",\"source\":\"Vital32-prototype\"}";
  fbPutJson(String("/users/") + FB_USER_UID + "/vital32/fall_events/" + String(timestampMs), j);
}
