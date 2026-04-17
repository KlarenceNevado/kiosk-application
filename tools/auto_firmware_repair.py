import subprocess
import time
import os
import sys

def run_command(command, description):
    print(f"\n[EXEC] {description}...")
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True, shell=True)
        print(f"[SUCCESS] {description} complete.")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] {description} failed.")
        print(f"Error Message: {e.stderr}")
        return None

def main():
    # Paths
    project_root = r"c:\KioskApplication\kiosk_application"
    ino_path = os.path.join(project_root, "hardware", "esp32_sensor_hub", "esp32_sensor_hub.ino")
    fqbn = "esp32:esp32:esp32"
    port = "COM10"
    
    print("==================================================")
    print("[ROBOT] Automated Kiosk Hardware Repair System")
    print("==================================================")
    
    # 1. Compile
    compile_cmd = f'arduino-cli compile --fqbn {fqbn} "{ino_path}"'
    comp_out = run_command(compile_cmd, "Compiling Firmware")
    if comp_out is None: return

    # 2. Upload (Using slower baudrate for stability over extenders)
    upload_cmd = f'arduino-cli upload -p {port} --fqbn {fqbn} --upload-property upload.speed=115200 "{ino_path}"'
    up_out = run_command(upload_cmd, f"Flashing ESP32 on {port} (Slower Speed)")
    if up_out is None:
        print("\n[TIP] If you get 'Access Denied', make sure the Kiosk App and Arduino Serial Monitor are CLOSED.")
        return

    # 3. Wait for Boot sequence
    print("\n[WAIT] Allowing 8 seconds for ESP32 to finish bootloader sequence...")
    time.sleep(8)

    # 4. Verify Signals
    verify_script = os.path.join(project_root, "tools", "test_usb_signals.py")
    verify_cmd = f"python \"{verify_script}\""
    ver_out = run_command(verify_cmd, "Verifying Hardware Signal Link")
    
    # 5. Save Report
    with open("repair_report.md", "w") as f:
        f.write("# Automated Hardware Repair Report\n\n")
        f.write(f"**Timestamp**: {time.ctime()}\n")
        f.write(f"**Port**: {port}\n\n")
        f.write("## Compilation Results\n")
        f.write(f"```\n{comp_out}\n```\n\n")
        f.write("## Flash Results\n")
        f.write(f"```\n{up_out}\n```\n\n")
        f.write("## Signal Verification Result\n")
        f.write(f"```\n{ver_out if ver_out else 'FAILED'}\n```\n\n")
        
    print("\n==================================================")
    print("✅ Repair Cycle Complete. See 'repair_report.md'.")
    print("==================================================")

if __name__ == "__main__":
    main()
