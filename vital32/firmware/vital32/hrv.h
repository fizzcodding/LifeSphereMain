#pragma once
#include <Arduino.h>
#include <math.h>

// Feed accepted beat-to-beat intervals (IBIs) in milliseconds, not BPM values.
// RMSSD and SDNN are short-window estimates; they are not medical assessments.
struct HRVCalculator {
  static constexpr uint8_t CAPACITY = 60;
  uint16_t ibi[CAPACITY] = {};
  uint8_t count = 0;
  uint8_t next = 0;
  float rmssdMs = NAN;
  float sdnnMs = NAN;
  bool valid = false;
};

inline void hrvReset(HRVCalculator &h) {
  h = HRVCalculator{};
  h.rmssdMs = NAN; h.sdnnMs = NAN;
}
inline void hrvAddIBI(HRVCalculator &h, uint16_t ibiMs) {
  if (ibiMs < 300 || ibiMs > 2000) return; // reject implausible intervals
  h.ibi[h.next] = ibiMs;
  h.next = (h.next + 1) % HRVCalculator::CAPACITY;
  if (h.count < HRVCalculator::CAPACITY) ++h.count;
  if (h.count < 3) { h.valid = false; return; }

  double mean = 0.0;
  for (uint8_t i = 0; i < h.count; ++i) {
    const uint8_t idx = (h.next + HRVCalculator::CAPACITY - h.count + i) % HRVCalculator::CAPACITY;
    mean += h.ibi[idx];
  }
  mean /= h.count;
  double sumSq = 0.0, diffSq = 0.0;
  uint16_t previous = 0;
  for (uint8_t i = 0; i < h.count; ++i) {
    const uint8_t idx = (h.next + HRVCalculator::CAPACITY - h.count + i) % HRVCalculator::CAPACITY;
    const uint16_t current = h.ibi[idx];
    const double d = current - mean;
    sumSq += d * d;
    if (i > 0) {
      const double delta = (double)current - previous;
      diffSq += delta * delta;
    }
    previous = current;
  }
  h.sdnnMs = sqrt(sumSq / (h.count - 1));
  h.rmssdMs = sqrt(diffSq / (h.count - 1));
  h.valid = true;
}
