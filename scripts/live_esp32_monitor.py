import serial
import time
import json
import sys

PORT = "COM10"
BAUD = 115200

print(f"--- Connecting to ESP32 on {PORT} at {BAUD} baud ---")
print("Collecting 3 reads for Antigravity test...\n")

try:
    with serial.Serial(PORT, BAUD, timeout=1) as ser:
        reads = 0
        while reads < 3:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if not line:
                continue
                
            try:
                # Try to parse it as JSON so we can display it cleanly
                data = json.loads(line)
                
                print(f"[{time.strftime('%H:%M:%S')}] HEARTBEAT:")
                print(f"  Temp (MLX):    {data.get('mlx_status', 'ERROR')} | Value: {data.get('mlx_val', 0.0)}")
                print(f"  Weight (HX711): {data.get('hx711_status', 'ERROR')} | Value: {data.get('hx711_val', 0.0)}")
                print("-" * 50)
                reads += 1
                
            except json.JSONDecodeError:
                # If it's not JSON, just print it plain
                print(f"RAW MSG: {line}")
                
except serial.SerialException as e:
    print(f"\nError connecting: {e}")
except KeyboardInterrupt:
    print("\n\Stopped listening.")
    sys.exit(0)

