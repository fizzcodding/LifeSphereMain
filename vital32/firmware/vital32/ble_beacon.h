#pragma once
#include <Arduino.h>
#include <NimBLEDevice.h>

#define VITAL32_BLE_UUID "7a1f0001-5c3e-4b8a-9d2e-1f6b8c0a4e11"

static bool vital32BleOk = false;

static void bleBeaconStart() {
  NimBLEDevice::init("Vital32");
  NimBLEDevice::setPower(ESP_PWR_LVL_P3);
  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(VITAL32_BLE_UUID);
  adv->setScanResponse(false);
  adv->setAdvertisementType(BLE_GAP_CONN_MODE_NON);
  adv->setMinInterval(160);
  adv->setMaxInterval(160);
  vital32BleOk = adv->start();
}