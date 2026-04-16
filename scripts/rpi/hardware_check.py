import serial
import time
import json
import sys

def check_hub(port):
    print(f"--- Probing Hub on {port} (115200) ---")
    try:
        ser = serial.Serial(port, 115200, timeout=2)
        time.sleep(2) # Wait for reset
        ser.reset_input_buffer()
        
        # Try to read 5 lines
        count = 0
        while count < 5:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                print(f"  [RAW]: {line}")
                # Check for JSON or CSV
                if "{" in line and "}" in line:
                    print("  [DETECTION]: JSON detected")
                elif ":" in line:
                    print("  [DETECTION]: CSV detected (T: or W: or H:)")
                count += 1
        ser.close()
        return True
    except Exception as e:
        print(f"  [ERROR]: {e}")
        return False

def check_oximeter(port):
    print(f"--- Probing Oximeter on {port} (19200) ---")
    try:
        ser = serial.Serial(port, 19200, timeout=3)
        # Read 18 bytes (2 packets)
        raw = ser.read(18)
        if len(raw) >= 9:
            print(f"  [RAW]: {raw.hex(' ')}")
            # Check CMS50D+ 9-byte sync (bit 7 must be 1 on byte 0)
            if raw[0] & 0x80:
                spo2 = raw[4]
                bpm = raw[5]
                print(f"  [DETECTION]: 9-byte Oximeter packet found! SpO2={spo2}%, BPM={bpm}")
                ser.close()
                return True
        ser.close()
        print("  [FAIL]: No valid sync byte found.")
        return False
    except Exception as e:
        print(f"  [ERROR]: {e}")
        return False

if __name__ == "__main__":
    print("========================================")
    print("  ISLA VERDE KIOSK HARDWARE DIAGNOSTIC  ")
    print("========================================\n")
    
    ports = ["/dev/ttyUSB0", "/dev/ttyUSB1"]
    
    hub_ok = check_hub(ports[0])
    print("")
    oxi_ok = check_oximeter(ports[1])
    
    print("\n========================================")
    status = "READY" if (hub_ok and oxi_ok) else "HARDWARE ISSUES DETECTED"
    print(f"  FINAL STATUS: {status}")
    print("========================================")
