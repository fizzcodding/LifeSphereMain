#pragma once

#include <Arduino.h>

#define RELAY_COUNT 5
#define RELAY_ACTIVE_LOW 1

struct RelayChannel {
  uint8_t gpio;
  const char *name;
  bool state;
};

static RelayChannel relayChannels[RELAY_COUNT] = {
  {26, "Living room light", false},
  {27, "Bedroom light", false},
  {14, "AC / fan", false},
  {12, "TV power", false},
  {13, "Main door lock", false},
};

inline uint8_t relayLevel(bool on) {
#if RELAY_ACTIVE_LOW
  return on ? LOW : HIGH;
#else
  return on ? HIGH : LOW;
#endif
}

inline void relayInit() {
  for (uint8_t i = 0; i < RELAY_COUNT; i++) {
    pinMode(relayChannels[i].gpio, OUTPUT);
    digitalWrite(relayChannels[i].gpio, relayLevel(false));
    relayChannels[i].state = false;
  }
}

inline int relayIndexForGpio(int gpio) {
  for (uint8_t i = 0; i < RELAY_COUNT; i++) {
    if (relayChannels[i].gpio == gpio) return i;
  }
  return -1;
}

inline bool relayApply(int gpio, bool on) {
  int index = relayIndexForGpio(gpio);
  if (index < 0) return false;
  if (relayChannels[index].state == on) return true;

  digitalWrite(relayChannels[index].gpio, relayLevel(on));
  relayChannels[index].state = on;

  Serial.printf("[relay] GPIO%-2d %-18s -> %s\n", gpio, relayChannels[index].name,
                on ? "ON" : "OFF");
  return true;
}

inline void relayAllOff() {
  for (uint8_t i = 0; i < RELAY_COUNT; i++) {
    digitalWrite(relayChannels[i].gpio, relayLevel(false));
    relayChannels[i].state = false;
  }
}
