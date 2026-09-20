#pragma once

#define SAMPLE_RATE 16000
#define SERIAL_BAUD 921600

#define PIN_MIC_BCLK 5
#define PIN_MIC_WS 4
#define PIN_MIC_DIN 6

#define PIN_AMP_BCLK 15
#define PIN_AMP_LRC 16
#define PIN_AMP_DIN 7

#define PIN_BTN 0

#define MIC_SHIFT 12
#define MIC_SETTLE_MS 120

#define PLAY_CHUNK 1024
#define RX_FRAMES 512
#define MAX_REC_MS 30000
#define MAX_PLAY_BYTES 4000000
