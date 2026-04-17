import subprocess
import time
import os
import sys

# No emojis allowed here to avoid Windows terminal crashes
def log(msg):
    timestamp = time.strftime("%H:%M:%S")
    formatted = f"[{timestamp}] {msg}"
    print(formatted)
    try:
        with open("MORNING_REPORT.txt", "a") as f:
            f.write(formatted + "\n")
    except:
        pass

def run_repair():
    project_root = r"c:\KioskApplication\kiosk_application"
    repair_script = os.path.join(project_root, "tools", "auto_firmware_repair.py")
    cmd = f"python \"{repair_script}\""
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        return result.stdout, result.returncode == 0
    except Exception as e:
        return str(e), False

def main():
    if os.path.exists("MORNING_REPORT.txt"):
        try:
            os.remove("MORNING_REPORT.txt")
        except:
            pass

    log("[DAEMON] OVERNIGHT REPAIR DAEMON STARTED")
    log("Status: Waiting for 'Clean Boot' (Unplug/Replug sensors)...")
    
    attempt = 0
    while attempt < 100: 
        attempt += 1
        log(f"Attempt #{attempt} - Starting Repair Cycle...")
        
        output, success = run_repair()
        
        if success and "[OK] SIGNAL DETECTED" in output:
            log("[SUCCESS] Firmware flashed and Signals detected.")
            log("REPAIR COMPLETE. You can now plug sensors back in one-by-one in the morning.")
            break
        else:
            if "Packet content transfer stopped" in output or "Access is denied" in output:
                log("[WARNING] Port Busy or Link Unstable. Check USB cable.")
            else:
                log("[FAIL] Flash failed or no signals yet. Retrying in 30 seconds...")
            
        time.sleep(30)

    log("[END] DAEMON SESSION FINISHED.")

if __name__ == "__main__":
    main()
