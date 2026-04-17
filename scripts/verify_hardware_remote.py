import paramiko

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

script_content = r'''
import serial, time, os
def sniff(p, b, label):
    print(f"Testing {label} speed ({b} baud)...")
    try:
        ser = serial.Serial(p, b, timeout=3)
        time.sleep(1)
        raw = ser.read(10)
        ser.close()
        if raw:
            print(f"  [FOUND DATA] Raw Hex: {raw.hex()}")
            return True
        return False
    except:
        return False

print("\n--- RPI KERNEL LOGS (USB ERRORS) ---")
os.system('dmesg | grep -i usb | tail -n 20')

print("\n--- BLUETOOTH SCAN (CONTEC ALTERNATIVE) ---")
os.system('hciconfig -a')
os.system('bluetoothctl --timeout 5 scan on')

print("\n--- GPIO UART CHECK ---")
os.system('ls -l /dev/ttyAMA0 /dev/ttyS0')
print("--- SCAN COMPLETE ---")
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect(ip, username=username, password=password)
    with client.open_sftp().file('/home/kiosk/hardware_check.py', 'w') as f:
        f.write(script_content)
    stdin, stdout, stderr = client.exec_command('python3 /home/kiosk/hardware_check.py')
    print(stdout.read().decode())
    client.close()
except Exception as e:
    print(f"Error: {e}")
