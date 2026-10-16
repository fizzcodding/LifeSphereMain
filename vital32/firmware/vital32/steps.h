#pragma once
#include <Arduino.h>
#include <math.h>

// Simple acceleration-magnitude step detector. Requires personal threshold tuning.
struct StepCounter {
  uint32_t count = 0;
  uint32_t lastStepMs = 0;
  float baseline = 1.0f;
  bool wasAbove = false;
};

inline void stepUpdate(StepCounter &sc, float axG, float ayG, float azG, uint32_t nowMs) {
  const float magnitude = sqrtf(axG * axG + ayG * ayG + azG * azG);
  sc.baseline = 0.92f * sc.baseline + 0.08f * magnitude;
  const bool above = fabsf(magnitude - sc.baseline) > 0.16f;
  const uint32_t interval = nowMs - sc.lastStepMs;
  if (above && !sc.wasAbove && (sc.lastStepMs == 0 || interval >= 280) &&
      (sc.lastStepMs == 0 || interval <= 2000)) {
    if (sc.lastStepMs != 0) ++sc.count;
    sc.lastStepMs = nowMs;
  }
  sc.wasAbove = above;
}
inline uint32_t stepGet(const StepCounter &sc) { return sc.count; }
inline void stepReset(StepCounter &sc) { sc = StepCounter{}; }
