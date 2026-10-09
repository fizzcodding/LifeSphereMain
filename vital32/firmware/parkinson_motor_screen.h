#pragma once
#include <Arduino.h>
#include <math.h>

#define MOTOR_WINDOW 128
#define MOTOR_SAMPLE_HZ 50.0f

struct MotorFeatures {
  float gyroRms = NAN;
  float tremorBandPower = NAN;
  float tremorBandRatio = NAN;
  bool ready = false;
};

class MotorFeatureWindow {
 public:
  void add(float gx, float gy, float gz) {
    float magnitude = sqrtf(gx * gx + gy * gy + gz * gz);
    samples[index] = magnitude;
    index++;
    if (index >= MOTOR_WINDOW) {
      index = 0;
      full = true;
      calculate();
    }
  }

  const MotorFeatures& get() const { return features; }

 private:
  float samples[MOTOR_WINDOW] = {};
  uint16_t index = 0;
  bool full = false;
  MotorFeatures features;

  float goertzelPower(float frequency, float mean) {
    float omega = 2.0f * PI * frequency / MOTOR_SAMPLE_HZ;
    float coeff = 2.0f * cosf(omega);
    float q0 = 0, q1 = 0, q2 = 0;
    for (uint16_t i = 0; i < MOTOR_WINDOW; i++) {
      q0 = (samples[i] - mean) + coeff * q1 - q2;
      q2 = q1;
      q1 = q0;
    }
    float power = q1 * q1 + q2 * q2 - coeff * q1 * q2;
    return power > 0 ? power : 0;
  }

  void calculate() {
    float mean = 0;
    for (uint16_t i = 0; i < MOTOR_WINDOW; i++) mean += samples[i];
    mean /= MOTOR_WINDOW;
    float variance = 0;
    for (uint16_t i = 0; i < MOTOR_WINDOW; i++) {
      float d = samples[i] - mean;
      variance += d * d;
    }
    features.gyroRms = sqrtf(variance / MOTOR_WINDOW);
    float band = 0;
    float total = 0;
    for (float f = 3.0f; f <= 7.0f; f += 0.5f) {
      float p = goertzelPower(f, mean);
      band += p;
    }
    for (float f = 0.5f; f <= 12.0f; f += 0.5f) total += goertzelPower(f, mean);
    features.tremorBandPower = band;
    features.tremorBandRatio = total > 0 ? band / total : 0;
    features.ready = full;
  }
};
