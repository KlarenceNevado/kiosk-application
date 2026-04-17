import paramiko

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

script_content = r'''
import serial, time, os
print("\n--- LIVE HARDWARE TEST ---")

try:
    if os.path.exists("/dev/hidraw1"):
        f=open("/dev/hidraw1", "rb")
        os.set_blocking(f.fileno(), False)
        time.sleep(1)
        d=f.read(50)
        if d: print("[SUCCESS] BLOOD PRESSURE (HIDRAW1) Is Working! Got", len(d), "bytes.")
        else: print("[WARNING] BP Monitor is connected but silent (try measuring).")
        f.close()
    else: print("[ERROR] BP Monitor (hidraw1) Not Found. Check cable.")
except Exception as e: print("[ERROR] BP Error:", e)

try:
    if os.path.exists("/dev/ttyUSB0"):
        ser=serial.Serial("/dev/ttyUSB0", 19200, timeout=1)
        d=ser.read(10)
        if d: print("[SUCCESS] PULSE OXIMETER (TTYUSB0) Is Working! Got", len(d), "bytes.")
        else: print("[WARNING] Pulse Oximeter is connected but silent (put finger in).")
        ser.close()
    else: print("[ERROR] Pulse Oximeter (ttyUSB0) Not Found. Check cable.")
except Exception as e: print("[ERROR] Oximeter Error:", e)
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect(ip, username=username, password=password)
    with client.open_sftp().file('/home/kiosk/hardware_test.py', 'w') as f:
        f.write(script_content)
    
    stdin, stdout, stderr = client.exec_command('python3 /home/kiosk/hardware_test.py')
    print(stdout.read().decode())
    client.close()
except Exception as e:
    print(f"Error: {e}")
