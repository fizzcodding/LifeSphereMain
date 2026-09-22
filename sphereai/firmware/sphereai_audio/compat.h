#pragma once

#include <driver/i2s.h>

template <typename T>
static auto setMck(T &p, int) -> decltype(p.mck_io_num, void()) {
  p.mck_io_num = I2S_PIN_NO_CHANGE;
}

template <typename T>
static void setMck(T &, long) {}
