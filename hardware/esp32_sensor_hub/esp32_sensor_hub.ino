#include <Adafruit_MLX90614.h>
#include <Arduino.h>
#include <ArduinoJson.h>
#include <HX711.h>
#include <Wire.h>

// --- PIN DEFINITIONS ---
#define SDA_PIN 22
#define SCL_PIN 21
#define HX711_DT_PIN 16
#define HX711_SCK_PIN 17

// --- SENSOR OBJECTS ---
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
HX711 scale;

// Prototypes for IDE stability
void sendHeartbeat();

// --- CONFIGURATION ---
float calibration_factor = 2280.f;
const int HEARTBEAT_INTERVAL_MS = 1000;

// State Variables
unsigned long lastHeartbeatTime = 0;
String mlxStatus = "INIT";
String hx711Status = "INIT";

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Initialize I2C for MLX
  Wire.begin(SDA_PIN, SCL_PIN);
  if (mlx.begin()) {
    mlxStatus = "ACTIVE";
  } else {
    mlxStatus = "ERROR";
  }

  // Initialize HX711 (Weight)
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  if (scale.is_ready()) {
    scale.set_scale(calibration_factor);
    scale.tare();
    hx711Status = "ACTIVE";
  } else {
    hx711Status = "ERROR";
  }

  Serial.println("{\"device\": \"esp32\", \"status\": \"booted\", "
                 "\"test_signal\": \"OK\"}");
}

void loop() {
  unsigned long currentMillis = millis();

  // --- HEARTBEAT LOGIC ---
  if (currentMillis - lastHeartbeatTime >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatTime = currentMillis;
    sendHeartbeat();
  }

  // --- COMMAND HANDLING ---
  if (Serial.available()) {
    String incoming = Serial.readStringUntil('\n');
    incoming.trim();

    if (incoming == "tare" || incoming == "TARE") {
      scale.tare();
      Serial.println("{\"type\": \"status\", \"value\": \"tared\"}");
    } else if (incoming == "handshake" || incoming == "HANDSHAKE") {
      sendHeartbeat();
    }
  }
}

/**
 * sendHeartbeat - Sync with Arduino Cloud logic
 * Uses Zero-clamping and Fixed Precision (2 decimal places)
 */
void sendHeartbeat() {
  StaticJsonDocument<256> doc;
  doc["device"] = "esp32";

  // Temperature Check
  float tempC = mlx.readObjectTempC();
  if (isnan(tempC) || tempC < 0 || tempC > 100) {
    doc["mlx_status"] = "ERROR";
    doc["mlx_val"] = 0.0;
  } else {
    doc["mlx_status"] = "ACTIVE";
    doc["mlx_val"] = serialized(String(tempC, 1));
  }

  // Weight Check
  if (scale.is_ready()) {
    float weight = scale.get_units(5);
    if (weight < 0.1 && weight > -0.1)
      weight = 0.0; // Zero-clamping from Cloud Version
    doc["hx711_status"] = "ACTIVE";
    doc["hx711_val"] = serialized(String(weight, 2));
  } else {
    doc["hx711_status"] = "ERROR";
    doc["hx711_val"] = 0.0;
  }

  serializeJson(doc, (Print &)Serial);
  Serial.println();
}
