#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/RTDBHelper.h>
#include <addons/TokenHelper.h>

#include "mqtt_handler.h"
#include "relay_controller.h"
#include "secrets.h"

FirebaseData stream;
FirebaseData command;
FirebaseAuth firebaseAuth;
FirebaseConfig firebaseConfig;

static String pinsPath;
static bool streamAttached = false;

static void applyPinObject(const String &label, FirebaseJson &pin) {
  FirebaseJsonData gpioField;
  FirebaseJsonData stateField;

  if (!pin.get(gpioField, "pin") || !pin.get(stateField, "state")) return;

  int gpio = gpioField.to<int>();
  bool state = stateField.to<bool>();

  if (!relayApply(gpio, state)) {
    Serial.printf("[sync] \"%s\" targets unmapped GPIO%d\n", label.c_str(), gpio);
  }
}

static void applyPinCollection(FirebaseJson &pins) {
  size_t count = 0;
  FirebaseJson::IteratorValue item;

  pins.iteratorBegin(&count);
  for (size_t i = 0; i < count; i++) {
    item = pins.valueAt(i);
    if (item.type != FirebaseJson::JSON_OBJECT) continue;

    FirebaseJson child;
    child.setJsonData(item.value);
    applyPinObject(item.key, child);
  }
  pins.iteratorEnd();
}

static void onStreamData(FirebaseStream data) {
  Serial.printf("[sync] %s (%s)\n", data.dataPath().c_str(), data.dataType().c_str());

  if (data.dataType() == "json") {
    FirebaseJson &payload = data.jsonObject();

    if (data.dataPath() == "/") {
      applyPinCollection(payload);
      mqttPublishState();
      return;
    }

    applyPinObject(data.dataPath(), payload);
    mqttPublishState();
    return;
  }

  if (data.dataType() == "boolean" && data.dataPath().endsWith("/state")) {
    String parent = data.dataPath().substring(0, data.dataPath().lastIndexOf('/'));
    FirebaseJson pin;

    if (Firebase.RTDB.getJSON(&command, pinsPath + parent) &&
        command.dataType() == "json") {
      pin = command.jsonObject();
      applyPinObject(parent, pin);
      mqttPublishState();
    }
  }
}

static void onStreamTimeout(bool timeout) {
  if (timeout) Serial.println(F("[sync] stream timeout, resuming"));
  if (!stream.httpConnected()) {
    Serial.printf("[sync] error %d: %s\n", stream.httpCode(), stream.errorReason().c_str());
  }
}

static void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print(F("[wifi] connecting"));

  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print('.');
  }

  Serial.printf("\n[wifi] connected, ip=%s\n", WiFi.localIP().toString().c_str());
}

static void attachStream() {
  pinsPath = "/users/" + String(firebaseAuth.token.uid.c_str()) + "/virtualPins";
  Serial.printf("[sync] subscribing to %s\n", pinsPath.c_str());

  if (!Firebase.RTDB.beginStream(&stream, pinsPath)) {
    Serial.printf("[sync] subscribe failed: %s\n", stream.errorReason().c_str());
    return;
  }

  Firebase.RTDB.setStreamCallback(&stream, onStreamData, onStreamTimeout);
  streamAttached = true;
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println(F("\nHollowCore automation node"));

  relayInit();
  connectWifi();

  firebaseConfig.api_key = FIREBASE_API_KEY;
  firebaseConfig.database_url = FIREBASE_DATABASE_URL;
  firebaseConfig.token_status_callback = tokenStatusCallback;
  firebaseAuth.user.email = FIREBASE_USER_EMAIL;
  firebaseAuth.user.password = FIREBASE_USER_PASSWORD;

  Firebase.reconnectWiFi(true);
  Firebase.begin(&firebaseConfig, &firebaseAuth);

  stream.setResponseSize(4096);
  command.setResponseSize(2048);

  mqttSetup();
}

void loop() {
  if (!Firebase.ready()) return;

  if (!streamAttached) {
    attachStream();
    return;
  }

  mqttLoop();
}
