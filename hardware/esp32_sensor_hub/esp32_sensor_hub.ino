#include <Wire.h>
#include <Adafruit_MLX90614.h>
#include <HX711.h>
#include <ArduinoJson.h>

// --- PIN DEFINITIONS ---
// MLX90614 (Temperature)
#define SDA_PIN 22
#define SCL_PIN 21

// HX711 (Weight/Load Cell)
#define HX711_DT_PIN 16
#define HX711_SCK_PIN 17

// --- SENSOR OBJECTS ---
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
HX711 scale;

// --- CONFIGURATION ---
float calibration_factor = 2280.f;  

// Timing
unsigned long lastTempRead = 0;
unsigned long lastWeightRead = 0;
const int TEMP_INTERVAL_MS = 1000;
const int WEIGHT_INTERVAL_MS = 500;

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  Serial.println("{ \"type\": \"status\", \"value\": \"booting\" }");

  // Initialize Sensors
  Wire.begin(SDA_PIN, SCL_PIN);
  if (!mlx.begin()) {
    Serial.println("{ \"type\": \"error\", \"value\": \"MLX90614 error\" }");
  }

  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  if (scale.is_ready()) {
    scale.set_scale(calibration_factor);
    scale.tare();
  } else {
    Serial.println("{ \"type\": \"error\", \"value\": \"HX711 error\" }");
  }
}

void loop() {
  unsigned long currentMillis = millis();

  // --- READ TEMPERATURE ---
  if (currentMillis - lastTempRead >= TEMP_INTERVAL_MS) {
    lastTempRead = currentMillis;
    double tempC = mlx.readObjectTempC();
    if (!isnan(tempC) && tempC > 0) sendJsonData("temp", tempC);
  }

  // --- READ WEIGHT ---
  if (currentMillis - lastWeightRead >= WEIGHT_INTERVAL_MS) {
    lastWeightRead = currentMillis;
    if (scale.is_ready()) {
      float weight = scale.get_units(5);
      if (weight < 0.05 && weight > -0.05) weight = 0.0;
      sendJsonData("weight", weight);
    }
  }

  // --- COMMANDS ---
  if (Serial.available()) {
    String incoming = Serial.readStringUntil('\n');
    incoming.trim();
    
    if (incoming.indexOf("tare") != -1) {
       scale.tare();
       Serial.println("{ \"type\": \"status\", \"value\": \"tared\" }");
    } else if (incoming.indexOf("handshake") != -1 || incoming == "HANDSHAKE") {
       Serial.println("{ \"type\": \"status\", \"value\": \"ready\" }");
    }
  }
}

void sendJsonData(String type, float value) {
  StaticJsonDocument<128> doc;
  doc["type"] = type;
  doc["value"] = serialized(String(value, (type == "weight" ? 2 : 1)));
  serializeJson(doc, Serial);
  Serial.println();
  
  // Minimal CSV Fallback
  if (type == "weight") {
    Serial.print("W:");
    Serial.println(String(value, 2));
  } else if (type == "temp") {
    Serial.print("T:");
    Serial.println(String(value, 1));
  }
}
