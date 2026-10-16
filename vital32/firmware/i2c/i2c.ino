#include <Wire.h>

void scanBus(TwoWire &bus, const char *name) {
  Serial.print(name);
  Serial.println(":");
  int count = 0;
  for (uint8_t addr = 1; addr < 127; addr++) {
    bus.beginTransmission(addr);
    if (bus.endTransmission() == 0) {
      Serial.print("  0x");
      if (addr < 16) Serial.print("0");
      Serial.println(addr, HEX);
      count++;
    }
  }
  if (count == 0) Serial.println("  none");
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Wire.begin(21, 22);
  Wire1.begin(19, 18);
}

void loop() {
  scanBus(Wire, "Wire (21/22)");
  scanBus(Wire1, "Wire1 (19/18)");
  Serial.println();
  delay(3000);
}