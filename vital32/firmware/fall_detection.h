#pragma once
#include <Arduino.h>
#include <math.h>

#define FALL_FREEFALL_G_THRESHOLD 0.4f
#define FALL_IMPACT_G_THRESHOLD 2.5f
#define FALL_IMPACT_WINDOW_MS 500
#define FALL_STILLNESS_DURATION_MS 3000
#define FALL_STILLNESS_G_THRESHOLD 0.3f

// Prototype heuristic only; validate against staged, safe test cases.
enum class FallState { IDLE, FREEFALL_DETECTED, IMPACT_DETECTED, CONFIRMED };

struct FallDetector {
  FallState state;
  unsigned long freefall_ts;
  unsigned long impact_ts;
  float impact_peak_g;
  bool fall_event_pending;
  FallDetector() : state(FallState::IDLE), freefall_ts(0), impact_ts(0), impact_peak_g(0.0f), fall_event_pending(false) {}
};

static inline float fallResultantG(float ax, float ay, float az) {
  return sqrtf(ax * ax + ay * ay + az * az);
}

static bool fallUpdate(FallDetector& fd, float ax, float ay, float az, unsigned long now_ms) {
  float mag = fallResultantG(ax, ay, az);
  switch (fd.state) {
    case FallState::IDLE:
      if (mag < FALL_FREEFALL_G_THRESHOLD) {
        fd.state = FallState::FREEFALL_DETECTED;
        fd.freefall_ts = now_ms;
        fd.impact_peak_g = 0.0f;
      }
      break;
    case FallState::FREEFALL_DETECTED:
      if (now_ms - fd.freefall_ts > FALL_IMPACT_WINDOW_MS) {
        fd.state = FallState::IDLE;
      } else if (mag > FALL_IMPACT_G_THRESHOLD) {
        fd.state = FallState::IMPACT_DETECTED;
        fd.impact_ts = now_ms;
        fd.impact_peak_g = mag;
      }
      break;
    case FallState::IMPACT_DETECTED:
      if (mag > fd.impact_peak_g) fd.impact_peak_g = mag;
      if (fabsf(mag - 1.0f) > FALL_STILLNESS_G_THRESHOLD) fd.impact_ts = now_ms;
      if (now_ms - fd.impact_ts >= FALL_STILLNESS_DURATION_MS) {
        fd.state = FallState::CONFIRMED;
        fd.fall_event_pending = true;
        return true;
      }
      break;
    case FallState::CONFIRMED:
      fd.state = FallState::IDLE;
      break;
  }
  return false;
}

static void fallReset(FallDetector& fd) {
  fd.state = FallState::IDLE;
  fd.freefall_ts = 0;
  fd.impact_ts = 0;
  fd.impact_peak_g = 0.0f;
  fd.fall_event_pending = false;
}
