#pragma once
#include <Arduino.h>
#include <math.h>

// Prototype threshold heuristic only. It cannot reliably identify every fall.
struct FallDetector {
  enum State : uint8_t { IDLE, FREEFALL, IMPACT, WAIT_STILL } state = IDLE;
  uint32_t stateSince = 0;
  uint32_t impactAt = 0;
  float impactPeakG = 0.0f;
  bool eventPending = false;
};

inline bool fallUpdate(FallDetector &f, float axG, float ayG, float azG, uint32_t nowMs) {
  const float mag = sqrtf(axG * axG + ayG * ayG + azG * azG);
  switch (f.state) {
    case FallDetector::IDLE:
      if (mag < 0.40f) { f.state = FallDetector::FREEFALL; f.stateSince = nowMs; }
      break;
    case FallDetector::FREEFALL:
      if (mag > 2.50f) {
        f.state = FallDetector::IMPACT; f.impactAt = nowMs; f.stateSince = nowMs; f.impactPeakG = mag;
      } else if (nowMs - f.stateSince > 500) f.state = FallDetector::IDLE;
      break;
    case FallDetector::IMPACT:
      if (mag > f.impactPeakG) f.impactPeakG = mag;
      if (nowMs - f.impactAt > 500) f.state = FallDetector::IDLE;
      else if (nowMs - f.stateSince >= 100) { f.state = FallDetector::WAIT_STILL; f.stateSince = nowMs; }
      break;
    case FallDetector::WAIT_STILL:
      if (fabsf(mag - 1.0f) > 0.30f) f.stateSince = nowMs;
      if (nowMs - f.stateSince >= 3000) {
        f.state = FallDetector::IDLE; f.eventPending = true; return true;
      }
      if (nowMs - f.impactAt > 5000) f.state = FallDetector::IDLE;
      break;
  }
  return false;
}
