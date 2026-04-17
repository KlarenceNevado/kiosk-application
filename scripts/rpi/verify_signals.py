import serial
import json
import os
import glob
import time

def scan_ports():
    print("\n--- 🔍 Kiosk Hardware Diagnostic: Signal Sniffer ---")
    ports = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*')
    if not ports:
        print("❌ No USB Serial devices found at /dev/ttyUSB* or /dev/ttyACM*")
        return

    for port in ports:
        print(f"\n📡 Sniffing Port: {port} (115200 baud)...")
        try:
            ser = serial.Serial(port, 115200, timeout=2)
            # Read for 3 seconds to catch a heartbeat
            start_time = time.time()
            found_json = False
            
            while time.time() - start_time < 3:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"   RAW: {line}")
                    if line.startswith('{') and line.endswith('}'):
                        try:
                            data = json.loads(line)
                            if data.get('device') == 'esp32':
                                print(f"   ✅ SUCCESS: Found ESP32 Hub Heartbeat!")
                                print(f"   📊 DATA: Weight={data.get('hx711_val')}kg, Temp={data.get('mlx_val')}°C")
                                found_json = True
                                break
                        except:
                            pass
            ser.close()
            if not found_json:
                print("   ℹ️ Port active but no valid ESP32 JSON found. Might be Oximeter (try 19200 baud).")
        except Exception as e:
            print(f"   ❌ ERROR: {e}")

    # Check Blood Pressure HID
    print("\n🩸 Checking Blood Pressure (HID)...")
    if os.path.exists('/dev/hidraw1'):
        print("   ✅ /dev/hidraw1 EXISTS. Permissions: " + oct(os.stat('/dev/hidraw1').st_mode)[-3:])
    elif os.path.exists('/dev/hidraw0'):
        print("   ✅ /dev/hidraw0 EXISTS. Permissions: " + oct(os.stat('/dev/hidraw0').st_mode)[-3:])
    else:
        print("   ❌ No /dev/hidraw devices found for Blood Pressure.")

    print("\n--- Diagnostic Complete ---")

if __name__ == "__main__":
    scan_ports()
