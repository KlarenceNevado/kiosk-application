try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("❌ Error: 'pyserial' library not found.")
    print("👉 Please run: pip install pyserial")
    sys.exit(1)

import json
import time
import sys

def test_sensors():
    print("[SCAN] Isla Verde Kiosk - Hardware Testing Ground")
    print("-------------------------------------------")
    
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("[ERR] No COM/Serial ports found. Check your USB connections!")
        return

    print(f"[INFO] Found {len(ports)} ports. Ready to sniff signals...")
    
    # Try common baud rates (115200 first for ESP32 Hub)
    baud_rates = [115200, 9600]
    
    for p in ports:
        print(f"\n[PORT] PROBING: {p.device} ({p.description})")
        
        for baud in baud_rates:
            try:
                print(f"   Trying {baud} baud...", end='\r')
                with serial.Serial(p.device, baud, timeout=2) as ser:
                    ser.reset_input_buffer()
                    # Wait for data (Wait longer for ESP32 boot sequence)
                    start_time = time.time()
                    while time.time() - start_time < 6:
                        line = ser.readline().decode('utf-8', errors='ignore').strip()
                        if line:
                            # Skip standard ESP32 bootloader garbage/headers
                            if "ets " in line or "boot:" in line or "waiting for download" in line:
                                print(f"   [BOOT] Saw bootloader message, waiting for app code...")
                                continue
                                
                            print(f"\n   [OK] SIGNAL DETECTED at {baud} baud!")
                            print(f"   [DATA] RAW: {line}")
                            
                            # Try to parse JSON (for ESP32 Hub)
                            try:
                                data = json.loads(line)
                                if 'device' in data:
                                    print(f"   [ID] ESP32 Sensor Hub Detected!")
                                    print(f"   [VAL] Weight: {data.get('hx711_val')}kg | Temp: {data.get('mlx_val')}C")
                                    break # Found what we wanted
                            except:
                                if "BP" in line or "SYS" in line:
                                    print("   [ID] Blood Pressure Monitor detected.")
                                    break
                            
                            # If we get a valid string that isn't bootloader, we consider it a success
                            if len(line) > 5 and not any(ord(c) > 127 for c in line):
                                break
                    else:
                        continue 
                    break 
            except Exception as e:
                continue

    print("\n-------------------------------------------")
    print("[FINISH] Testing Complete. If you see JSON data above, your system is 100% READY.")
    print("[TIP] To clear the red marks in your IDE, please press 'Ctrl+Shift+P' and type 'Reload Window'.")

if __name__ == "__main__":
    test_sensors()
