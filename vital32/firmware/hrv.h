#pragma once
#include <Arduino.h>
#include <math.h>

#define STEP_ACCEL_THRESHOLD_G 0.15f
#define STEP_MIN_INTERVAL_MS 250
#define STEP_MAX_INTERVAL_MS 2000
#define STEP_RESET_MIDNIGHT true

struct StepCounter {
  int steps;
  bool prev_above;
  unsigned long last_step_ts;
  float mag_filter;
  StepCounter() : steps(0), prev_above(false), last_step_ts(0), mag_filter(1.0f) {}
};

static void stepUpdate(StepCounter& sc, float ax, float ay, float az, unsigned long now_ms) {
  float mag = sqrtf(ax * ax + ay * ay + az * az);
  sc.mag_filter = 0.85f * sc.mag_filter + 0.15f * mag;
  bool above = fabsf(mag - sc.mag_filter) > STEP_ACCEL_THRESHOLD_G;
  if (above && !sc.prev_above) {
    unsigned long dt = now_ms - sc.last_step_ts;
    if (sc.last_step_ts == 0 || dt >= STEP_MIN_INTERVAL_MS) {
      if (sc.last_step_ts != 0 && dt <= STEP_MAX_INTERVAL_MS) sc.steps++;
      sc.last_step_ts = now_ms;
    }
  }
  sc.prev_above = above;
}

static void stepReset(StepCounter& sc) {
  sc.steps = 0;
  sc.prev_above = false;
  sc.last_step_ts = 0;
  sc.mag_filter = 1.0f;
}

static int stepGet(const StepCounter& sc) { return sc.steps; }
