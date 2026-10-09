#pragma once
#include <Arduino.h>
#include <math.h>

#define TEMP_MINUTE_BUCKET_MS 60000UL
#define TEMP_HISTORY_MINUTES 1440
#define TEMP_RATE_WINDOW_MINUTES 60
#define TEMP_RISE_THRESHOLD_C_PER_HOUR 0.28f
#define TEMP_CUSUM_DRIFT_ALLOWANCE_C 0.02f
#define TEMP_CUSUM_ALERT_THRESHOLD 3.0f
#define TEMP_MIN_VALID_C 10.0f
#define TEMP_MAX_VALID_C 50.0f

struct FeverTrend {
  float minuteHistory[TEMP_HISTORY_MINUTES];
  uint16_t historyCount;
  uint16_t historyIndex;
  float minuteSum;
  uint16_t minuteCount;
  uint32_t minuteStartedMs;
  uint32_t lastRateEvaluationMs;
  float rateCPerHour;
  float cusum;
  bool baselineReady;
  bool trendAlert;
  bool cusumAlert;
  uint8_t consecutiveRisingHours;
  float lastMinuteMean;
  FeverTrend() : historyCount(0), historyIndex(0), minuteSum(0), minuteCount(0), minuteStartedMs(0), lastRateEvaluationMs(0), rateCPerHour(NAN), cusum(0), baselineReady(false), trendAlert(false), cusumAlert(false), consecutiveRisingHours(0), lastMinuteMean(NAN) {
    for (uint16_t i = 0; i < TEMP_HISTORY_MINUTES; i++) minuteHistory[i] = NAN;
  }
};

static void feverTrendAddReading(FeverTrend& f, float tempC, uint32_t nowMs) {
  if (!isfinite(tempC) || tempC < TEMP_MIN_VALID_C || tempC > TEMP_MAX_VALID_C) return;
  if (f.minuteStartedMs == 0) f.minuteStartedMs = nowMs;
  f.minuteSum += tempC;
  f.minuteCount++;
  if ((uint32_t)(nowMs - f.minuteStartedMs) < TEMP_MINUTE_BUCKET_MS || f.minuteCount == 0) return;

  float minuteMean = f.minuteSum / f.minuteCount;
  f.minuteSum = 0;
  f.minuteCount = 0;
  f.minuteStartedMs = nowMs;

  if (f.historyCount >= TEMP_RATE_WINDOW_MINUTES) {
    uint16_t oneHourAgoIndex = (uint16_t)((f.historyIndex + TEMP_HISTORY_MINUTES - TEMP_RATE_WINDOW_MINUTES) % TEMP_HISTORY_MINUTES);
    float oneHourAgo = f.minuteHistory[oneHourAgoIndex];
    if (isfinite(oneHourAgo)) f.rateCPerHour = minuteMean - oneHourAgo;
  }

  if ((uint32_t)(nowMs - f.lastRateEvaluationMs) >= 3600000UL) {
    f.lastRateEvaluationMs = nowMs;
    if (isfinite(f.rateCPerHour) && f.rateCPerHour >= TEMP_RISE_THRESHOLD_C_PER_HOUR) {
      if (f.consecutiveRisingHours < 255) f.consecutiveRisingHours++;
    } else {
      f.consecutiveRisingHours = 0;
    }
    f.trendAlert = f.consecutiveRisingHours >= 3;
  }

  if (f.historyCount >= TEMP_HISTORY_MINUTES) {
    float sameTimeYesterday = f.minuteHistory[f.historyIndex];
    if (isfinite(sameTimeYesterday)) {
      float deviation = minuteMean - sameTimeYesterday;
      f.cusum = fmaxf(0.0f, f.cusum + deviation - TEMP_CUSUM_DRIFT_ALLOWANCE_C);
      f.baselineReady = true;
      f.cusumAlert = f.cusum >= TEMP_CUSUM_ALERT_THRESHOLD;
    }
  }

  f.lastMinuteMean = minuteMean;
  f.minuteHistory[f.historyIndex] = minuteMean;
  f.historyIndex = (uint16_t)((f.historyIndex + 1) % TEMP_HISTORY_MINUTES);
  if (f.historyCount < TEMP_HISTORY_MINUTES) f.historyCount++;
}

static const char* feverTrendLabel(const FeverTrend& f) {
  if (f.trendAlert || f.cusumAlert) return "TREND ANOMALY";
  if (!f.baselineReady) return "BUILDING BASELINE";
  return "NO TREND ALERT";
}
