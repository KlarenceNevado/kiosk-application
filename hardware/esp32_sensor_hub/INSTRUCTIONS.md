# ESP32 Sensor Hub Firmware Instructions

Your physical wiring is correct! However, the ESP32 needs this code to understand the sensors and convert their electrical signals into the JSON format that your Kiosk Application expects.

## Prerequisite: Download Arduino IDE
If you haven't already, download the Arduino IDE from [arduino.cc/en/software](https://www.arduino.cc/en/software).

## 1. Install ESP32 Board Manager
1. Open Arduino IDE.
2. Go to **File -> Preferences**.
3. In the "Additional Boards Manager URLs" field, paste:
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
4. Click OK.
5. Go to **Tools -> Board -> Boards Manager**.
6. Search for `esp32` and install the package by "Espressif Systems".

## 2. Install Required Libraries
You need to install three libraries to make this code work.
Go to **Sketch -> Include Library -> Manage Libraries** and search for:

1. `Adafruit MLX90614` by Adafruit
2. `HX711 Arduino Library` by Bogdan Necula
3. `ArduinoJson` by Benoit Blanchon (Version 6.x)

## 3. Upload the Code
1. Double-click the `esp32_sensor_hub.ino` file to open it in the Arduino IDE.
2. Plug your ESP32 into your PC via USB.
3. Go to **Tools -> Board** and select your ESP32 model (usually "DOIT ESP32 DEVKIT V1" or "ESP32 Dev Module").
4. Go to **Tools -> Port** and select the active COM port.
5. Click the **Upload** arrow button `->` in the top left corner.

## 4. Test the Sensors (Crucial Step!)
Before hooking it back up to your Kiosk software, verify it works manually:
1. With the ESP32 still plugged in, click the **Serial Monitor** icon (top right corner of Arduino IDE).
2. Change the baud rate drop-down in the corner of the monitor from "9600" to **115200**.
3. You should instantly start seeing scrolling text that looks exactly like this:
   `{"type":"temp","value":36.5}`
   `{"type":"weight","value":0.00}`

_Note for the scale: You will likely need to adjust the `calibration_factor` variable at the top of the `.ino` file to get accurate KG readings based on your specific load cell!_

Once you see those JSON strings streaming in the Serial Monitor, plug the ESP32 into your Kiosk platform, start your Flutter app, and your Hardware Dashboard will automatically pick it up!
