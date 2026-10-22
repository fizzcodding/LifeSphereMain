
#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>

// Must match the UUID Motor Muscle scans for.
#define BEACON_UUID "7a1f0001-5c3e-4b8a-9d2e-1f6b8c0a4e11"

#define DEVICE_NAME "HollowRover-Beacon"

BLEAdvertising* advertising = nullptr;

void setup() {
  Serial.begin(115200);
  delay(500);

  BLEDevice::init(DEVICE_NAME);

  // Create a service so the UUID is included in advertisements.
  BLEServer* server = BLEDevice::createServer();
  BLEService* service =
      server->createService(BLEUUID(BEACON_UUID));

  service->start();

  advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLEUUID(BEACON_UUID));
  advertising->setScanResponse(true);

  BLEDevice::startAdvertising();

  Serial.println("BLE advertiser started!");
  Serial.println("Name: HollowRover-Beacon");
  Serial.println("UUID: " BEACON_UUID);
}

void loop() {
  // Advertising continues without doing anything here.
  delay(1000);
}
