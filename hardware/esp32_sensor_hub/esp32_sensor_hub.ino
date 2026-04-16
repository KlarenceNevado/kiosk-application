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

// HC-SR04 (Height/IR Sensor)
#define TRIG_PIN 5
#define ECHO_PIN 18

// --- SENSOR OBJECTS ---
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
HX711 scale;

// --- CONFIGURATION ---
float calibration_factor = 2280.f;  
const float HEIGHT_OFFSET = 200.0; // Distance from floor to sensor in cm

// Timing
unsigned long lastTempRead = 0;
unsigned long lastWeightRead = 0;
unsigned long lastHeightRead = 0;
const int TEMP_INTERVAL_MS = 1000;
const int WEIGHT_INTERVAL_MS = 500;
const int HEIGHT_INTERVAL_MS = 1000;

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  // 1. Initialize Pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  Serial.println("{ \"type\": \"status\", \"value\": \"booting\" }");

  // 2. Initialize Sensors
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

float getDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  long duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout
  if (duration == 0) return 0;
  
  float distance = (duration * 0.0343) / 2; // cm
  return distance;
}

void loop() {
  unsigned long currentMillis = millis();

  // --- READ TEMPERATURE ---
  if (currentMillis - lastTempRead >= TEMP_INTERVAL_MS) {
    lastTempRead = currentMillis;
    double tempC = mlx.readObjectTempC();
    if (!isnan(tempC)) sendJsonData("temp", tempC);
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

  // --- READ HEIGHT (IR/Ultrasonic) ---
  if (currentMillis - lastHeightRead >= HEIGHT_INTERVAL_MS) {
    lastHeightRead = currentMillis;
    float dist = getDistance();
    if (dist > 10 && dist < 300) {
      float height = HEIGHT_OFFSET - dist;
      if (height < 0) height = 0;
      sendJsonData("height", height);
    }
  }

  // --- HANDSHAKE & COMMANDS ---
  if (Serial.available()) {
    String incoming = Serial.readStringUntil('\n');
    incoming.trim();
    
    if (incoming.indexOf("tare") != -1) {
       scale.tare();
       Serial.println("{ \"type\": \"status\", \"value\": \"tared\" }");
    } else if (incoming.indexOf("handshake") != -1 || incoming == "HANDSHAKE") {
       Serial.println("{ \"type\": \"status\", \"value\": \"ready\" }");
       Serial.println("STATUS:READY,V:1.0.0"); // Send both JSON and CSV
    }
  }
}

void sendJsonData(String type, float value) {
  StaticJsonDocument<128> doc;
  doc["type"] = type;
  doc["value"] = serialized(String(value, (type == "weight" ? 2 : 1)));
  serializeJson(doc, Serial);
  Serial.println();
  
  // Also send CSV for fallback/legacy support
  if (type == "weight") Serial.print("W:");
  else if (type == "temp") Serial.print("T:");
  else if (type == "height") Serial.print("H:");
  Serial.println(String(value, 2));
}
