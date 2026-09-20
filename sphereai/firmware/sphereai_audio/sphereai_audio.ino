#include <driver/i2s.h>
#include <esp_log.h>
#include <string.h>
#include "config.h"

#define MIC_PORT I2S_NUM_1
#define SPK_PORT I2S_NUM_0

static String lineBuf;
alignas(4) static uint8_t playBuf[PLAY_CHUNK];
alignas(4) static int16_t stereoBuf[PLAY_CHUNK];
alignas(4) static int32_t rxBuf[RX_FRAMES];
alignas(4) static int16_t outBuf[RX_FRAMES];
static bool btnWasDown = false;
static uint32_t btnLastMs = 0;

static void sendLine(const char *s) {
  Serial.print(s);
  Serial.print('\n');
}

static bool readLine(String &out) {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n') {
      out = lineBuf;
      lineBuf = "";
      out.trim();
      return true;
    }
    if (c != '\r') {
      lineBuf += c;
      if (lineBuf.length() > 64) {
        lineBuf = "";
      }
    }
  }
  return false;
}

static bool startMic() {
  i2s_config_t cfg;
  memset(&cfg, 0, sizeof(cfg));
  cfg.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX);
  cfg.sample_rate = SAMPLE_RATE;
  cfg.bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT;
  cfg.channel_format = I2S_CHANNEL_FMT_ONLY_LEFT;
  cfg.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  cfg.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  cfg.dma_buf_count = 8;
  cfg.dma_buf_len = 256;
  cfg.use_apll = false;

  i2s_pin_config_t pins;
  memset(&pins, 0, sizeof(pins));
  pins.bck_io_num = PIN_MIC_BCLK;
  pins.ws_io_num = PIN_MIC_WS;
  pins.data_out_num = I2S_PIN_NO_CHANGE;
  pins.data_in_num = PIN_MIC_DIN;

  if (i2s_driver_install(MIC_PORT, &cfg, 0, NULL) != ESP_OK) {
    return false;
  }
  if (i2s_set_pin(MIC_PORT, &pins) != ESP_OK) {
    i2s_driver_uninstall(MIC_PORT);
    return false;
  }
  return true;
}

static bool startSpk() {
  i2s_config_t cfg;
  memset(&cfg, 0, sizeof(cfg));
  cfg.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);
  cfg.sample_rate = SAMPLE_RATE;
  cfg.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
  cfg.channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT;
  cfg.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  cfg.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  cfg.dma_buf_count = 8;
  cfg.dma_buf_len = 256;
  cfg.use_apll = false;
  cfg.tx_desc_auto_clear = true;

  i2s_pin_config_t pins;
  memset(&pins, 0, sizeof(pins));
  pins.bck_io_num = PIN_AMP_BCLK;
  pins.ws_io_num = PIN_AMP_LRC;
  pins.data_out_num = PIN_AMP_DIN;
  pins.data_in_num = I2S_PIN_NO_CHANGE;

  if (i2s_driver_install(SPK_PORT, &cfg, 0, NULL) != ESP_OK) {
    return false;
  }
  if (i2s_set_pin(SPK_PORT, &pins) != ESP_OK) {
    i2s_driver_uninstall(SPK_PORT);
    return false;
  }
  return true;
}

static void doRecord(uint32_t ms) {
  const uint32_t totalBytes = ms * 32;
  bool ok = startMic();

  Serial.print("AUD ");
  Serial.print(totalBytes);
  Serial.print('\n');

  uint32_t remaining = totalBytes;
  if (ok) {
    size_t gotBytes = 0;
    uint32_t settleUntil = millis() + MIC_SETTLE_MS;
    while (millis() < settleUntil) {
      i2s_read(MIC_PORT, rxBuf, sizeof(rxBuf), &gotBytes, pdMS_TO_TICKS(100));
    }
    while (remaining >= 2) {
      size_t wantSamples = remaining / 2;
      if (wantSamples > RX_FRAMES) {
        wantSamples = RX_FRAMES;
      }
      gotBytes = 0;
      i2s_read(MIC_PORT, rxBuf, wantSamples * 4, &gotBytes, pdMS_TO_TICKS(500));
      size_t n = gotBytes / 4;
      if (n == 0) {
        break;
      }
      for (size_t i = 0; i < n; i++) {
        int32_t v = rxBuf[i] >> MIC_SHIFT;
        if (v > 32767) {
          v = 32767;
        }
        if (v < -32768) {
          v = -32768;
        }
        outBuf[i] = (int16_t)v;
      }
      Serial.write((uint8_t *)outBuf, n * 2);
      remaining -= n * 2;
    }
    i2s_driver_uninstall(MIC_PORT);
  }

  memset(outBuf, 0, sizeof(outBuf));
  while (remaining > 0) {
    size_t n = remaining > sizeof(outBuf) ? sizeof(outBuf) : remaining;
    Serial.write((uint8_t *)outBuf, n);
    remaining -= n;
  }
  sendLine("OK");
}

static void doPlay(uint32_t total) {
  if (!startSpk()) {
    sendLine("ERR spk_init");
    return;
  }
  sendLine("RDY");

  uint32_t remaining = total;
  while (remaining > 0) {
    size_t want = remaining > PLAY_CHUNK ? PLAY_CHUNK : remaining;
    size_t got = 0;
    uint32_t lastData = millis();
    while (got < want && millis() - lastData < 3000) {
      int n = Serial.readBytes(playBuf + got, want - got);
      if (n > 0) {
        got += n;
        lastData = millis();
      }
    }
    if (got < want) {
      break;
    }
    size_t samples = got / 2;
    const int16_t *in = (const int16_t *)playBuf;
    for (size_t i = 0; i < samples; i++) {
      stereoBuf[2 * i] = in[i];
      stereoBuf[2 * i + 1] = in[i];
    }
    size_t written = 0;
    i2s_write(SPK_PORT, stereoBuf, samples * 4, &written, portMAX_DELAY);
    Serial.write('K');
    remaining -= got;
  }
  delay(150);
  i2s_driver_uninstall(SPK_PORT);
  sendLine("DONE");
}

static void handleCommand(const String &cmd) {
  if (cmd == "PING") {
    sendLine("PONG");
    return;
  }
  if (cmd.startsWith("REC ")) {
    long ms = cmd.substring(4).toInt();
    if (ms < 100 || ms > MAX_REC_MS) {
      sendLine("ERR bad_ms");
      return;
    }
    doRecord((uint32_t)ms);
    return;
  }
  if (cmd.startsWith("PLAY ")) {
    long n = cmd.substring(5).toInt();
    if (n < 2 || n > MAX_PLAY_BYTES || (n & 1)) {
      sendLine("ERR bad_len");
      return;
    }
    doPlay((uint32_t)n);
    return;
  }
  sendLine("ERR unknown");
}

static void pollButton() {
  bool down = digitalRead(PIN_BTN) == LOW;
  uint32_t now = millis();
  if (down && !btnWasDown && now - btnLastMs > 250) {
    btnLastMs = now;
    sendLine("EVT BTN");
  }
  btnWasDown = down;
}

void setup() {
  esp_log_level_set("*", ESP_LOG_NONE);
  Serial.setRxBufferSize(8192);
  Serial.begin(SERIAL_BAUD);
  Serial.setTimeout(1000);
  pinMode(PIN_BTN, INPUT_PULLUP);
}

void loop() {
  String cmd;
  if (readLine(cmd)) {
    handleCommand(cmd);
  }
  pollButton();
}
