#pragma once
#include <Arduino.h>
#include <math.h>

// Basic rolling gyro feature summary for data collection only. Not a Parkinson's detector.
struct MotorFeatures { float gyroRms = 0, tremorBandPower = 0, tremorBandRatio = 0; bool ready = false; };
struct MotorFeatureWindow {
  static constexpr uint8_t N = 50;
  float mag[N] = {}; uint8_t next = 0, count = 0;
  MotorFeatures result;
  void add(float gx, float gy, float gz) {
    mag[next] = sqrtf(gx*gx + gy*gy + gz*gz);
    next = (next + 1) % N; if (count < N) ++count;
    if (count < N) { result.ready = false; return; }
    float mean = 0; for (uint8_t i=0;i<N;i++) mean += mag[i]; mean /= N;
    float variance = 0, high = 0;
    for (uint8_t i=0;i<N;i++) { float d=mag[i]-mean; variance += d*d; if (i>0) { float diff=mag[i]-mag[i-1]; high += diff*diff; } }
    result.gyroRms = sqrtf(variance/N);
    result.tremorBandPower = high/(N-1);
    result.tremorBandRatio = result.tremorBandPower/(result.tremorBandPower + variance/N + 1e-6f);
    result.ready = true;
  }
  const MotorFeatures& get() const { return result; }
};
