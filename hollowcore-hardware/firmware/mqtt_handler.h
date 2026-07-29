#pragma once

#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <WiFiClient.h>

#include "relay_controller.h"
#include "secrets.h"

#define MQTT_COMMAND_TOPIC "lifesphere/hollowcore/command"
#define MQTT_STATE_TOPIC "lifesphere/hollowcore/state"

static WiFiClient mqttWifiClient;
static PubSubClient mqttClient(mqttWifiClient);
static uint32_t lastMqttAttempt = 0;

inline void mqttPublishState() {
  if (!mqttClient.connected()) return;

  JsonDocument doc;
  for (uint8_t i = 0; i < RELAY_COUNT; i++) {
    doc[String(relayChannels[i].gpio)] = relayChannels[i].state;
  }

  char payload[256];
  size_t length = serializeJson(doc, payload, sizeof(payload));
  mqttClient.publish(MQTT_STATE_TOPIC, payload, length);
}

inline void mqttOnMessage(char *topic, byte *payload, unsigned int length) {
  JsonDocument doc;
  if (deserializeJson(doc, payload, length) != DeserializationError::Ok) {
    Serial.println(F("[mqtt] malformed command payload"));
    return;
  }

  int gpio = doc["pin"] | -1;
  if (gpio < 0) {
    Serial.println(F("[mqtt] command missing pin"));
    return;
  }

  bool state = doc["state"] | false;
  if (relayApply(gpio, state)) {
    mqttPublishState();
  } else {
    Serial.printf("[mqtt] GPIO%d is not a mapped relay\n", gpio);
  }
}

inline void mqttSetup() {
  mqttClient.setServer(MQTT_BROKER_HOST, MQTT_BROKER_PORT);
  mqttClient.setCallback(mqttOnMessage);
}

inline void mqttLoop() {
  if (mqttClient.connected()) {
    mqttClient.loop();
    return;
  }

  if (millis() - lastMqttAttempt < 5000) return;
  lastMqttAttempt = millis();

  if (mqttClient.connect(MQTT_CLIENT_ID)) {
    Serial.println(F("[mqtt] connected"));
    mqttClient.subscribe(MQTT_COMMAND_TOPIC);
    mqttPublishState();
  }
}
