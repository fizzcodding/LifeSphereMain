#pragma once
#include <Arduino.h>
#include <math.h>

// Experimental surface-temperature trend indicator; not fever diagnosis.
struct FeverTrend {
  static constexpr uint8_t N = 60;
  float minuteMeans[N] = {};
  uint8_t count = 0, next = 0;
  float minuteSum = 0.0f;
  uint16_t minuteSamples = 0;
  uint32_t minuteStart = 0, lastEval = 0;
  float rateCPerHour = NAN, cusum = 0.0f;
  bool baselineReady = false, trendAlert = false, cusumAlert = false;
  uint8_t highRateCount = 0;
  float lastTemp = NAN;
};
inline const char *feverTrendLabel(const FeverTrend &f) {
  if (f.trendAlert || f.cusumAlert) return "REVIEW_TREND";
  return f.baselineReady ? "NO_TREND_ALERT" : "LEARNING_BASELINE";
}
inline void feverTrendAddReading(FeverTrend &f, float tempC, uint32_t nowMs) {
  if (!isfinite(tempC) || tempC < 10.0f || tempC > 50.0f) return;
  f.lastTemp = tempC;
  if (f.minuteStart == 0) f.minuteStart = nowMs;
  f.minuteSum += tempC; ++f.minuteSamples;
  if (nowMs - f.minuteStart < 60000) return;
  const float mean = f.minuteSamples ? f.minuteSum / f.minuteSamples : tempC;
  f.minuteMeans[f.next] = mean;
  f.next = (f.next + 1) % FeverTrend::N;
  if (f.count < FeverTrend::N) ++f.count;
  f.minuteSum = 0; f.minuteSamples = 0; f.minuteStart = nowMs;
  if (f.count >= 60) {
    const uint8_t oneHourAgo = f.next; // oldest value once full circular buffer
    f.rateCPerHour = mean - f.minuteMeans[oneHourAgo];
    f.baselineReady = true;
    if (f.rateCPerHour > 0.28f) { if (f.highRateCount < 255) ++f.highRateCount; }
    else f.highRateCount = 0;
    f.trendAlert = f.highRateCount >= 3;
    // Positive cumulative deviation relative to rolling one-hour mean.
    float avg = 0; for (uint8_t i=0; i<f.count; ++i) avg += f.minuteMeans[i];
    avg /= f.count;
    f.cusum = fmaxf(0.0f, f.cusum + (mean - avg - 0.10f));
    f.cusumAlert = f.cusum > 1.5f;
  }
}
