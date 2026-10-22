#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

Adafruit_PWMServoDriver pca(0x40, Wire);
void setup() {
  Serial.begin(115200);
  delay(1000);

  Wire.begin(8, 9);
  Wire.setClock(100000);

  Serial.println("1: I2C started");

  pca.begin();
  Serial.println("2: PCA initialized");

  pca.reset();
  Serial.println("3: PCA reset");

  pca.setPWMFreq(50);
  Serial.println("4: PWM configured");
}

void loop() {
  delay(1000);
  Serial.println("Running");
}