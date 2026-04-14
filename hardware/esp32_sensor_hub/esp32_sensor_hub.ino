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
// IMPORTANT: You will need to calibrate this value using a known weight!
// If a 1kg weight shows up as 10000, your calibration factor is 10000.
// Adjust this number until the scale reads the correct value in kg.
float calibration_factor = 2280.f;  // <-- TUNE THIS VALUE

// Timing
unsigned long lastTempRead = 0;
unsigned long lastWeightRead = 0;
const int TEMP_INTERVAL_MS = 1000;   // Read temp every 1 second
const int WEIGHT_INTERVAL_MS = 500;  // Read weight every 500ms

void setup() {
  // 1. Initialize Serial Communication at 115200 baud
  // This matches the baud_rate setting in your Kiosk 'hardware_config.json'
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  // Send initialization handshake signature that the Flutter app expects
  Serial.println("{ \"type\": \"status\", \"value\": \"booting\" }");

  // 2. Initialize I2C for MLX90614
  Wire.begin(SDA_PIN, SCL_PIN);
  if (!mlx.begin()) {
    Serial.println("{ \"type\": \"error\", \"value\": \"MLX90614 not found. Check I2C wiring (SDA=22, SCL=21).\" }");
  }

  // 3. Initialize HX711
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  if (scale.is_ready()) {
    scale.set_scale(calibration_factor);
    scale.tare(); // Zero the scale on startup
  } else {
    Serial.println("{ \"type\": \"error\", \"value\": \"HX711 not found. Check wiring (DT=16, SCK=17).\" }");
  }
}

void loop() {
  unsigned long currentMillis = millis();

  // --- READ TEMPERATURE ---
  if (currentMillis - lastTempRead >= TEMP_INTERVAL_MS) {
    lastTempRead = currentMillis;

    // Read object temperature in Celsius
    double tempC = mlx.readObjectTempC();
    
    // Only send if valid reading
    if (!isnan(tempC) && tempC > -50 && tempC < 150) {
      sendJsonData("temp", tempC);
    }
  }

  // --- READ WEIGHT ---
  if (currentMillis - lastWeightRead >= WEIGHT_INTERVAL_MS) {
    lastWeightRead = currentMillis;

    if (scale.is_ready()) {
      // Get the weight (rounded to 2 decimal places for stability)
      float weight = scale.get_units(5); // Average of 5 readings
      
      // Prevent negative drift floating around 0
      if (weight < 0.05 && weight > -0.05) {
        weight = 0.0;
      }

      sendJsonData("weight", weight);
    }
  }

  // Check for incoming commands from Flutter App (e.g., TARE command)
  if (Serial.available()) {
    String incoming = Serial.readStringUntil('\n');
    if (incoming.indexOf("tare") != -1) {
       scale.tare();
       Serial.println("{ \"type\": \"status\", \"value\": \"tared\" }");
    }
  }
}

// Helper function to format and send JSON via Serial
void sendJsonData(String type, float value) {
  // Using ArduinoJson library for clean json creation
  StaticJsonDocument<128> doc;
  doc["type"] = type;
  
  // Format to 2 decimal places to prevent messy floats
  if (type == "weight") {
    doc["value"] = serialized(String(value, 2)); 
  } else {
    doc["value"] = serialized(String(value, 1)); // 1 dec for temp
  }

  serializeJson(doc, Serial);
  Serial.println(); // Send newline at the end!
}
