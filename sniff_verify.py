import paramiko

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

script_content = r'''
import serial, os, time
print("\n--- RPI LIVE SENSOR SNIFFER ---")

# 1. Test Oximeter
print("\n[OXIMETER TEST]")
path = "/dev/ttyUSB0"
if os.path.exists(path):
    print(f"Found {path}. Reading for 2 seconds...")
    try:
        ser = serial.Serial(path, 19200, timeout=1)
        data = ser.read(15)
        ser.close()
        if data:
            print(f"SUCCESS: Captured {len(data)} bytes of Pulse data.")
            print(f"HEX: {data.hex()}")
        else:
            print("IDLE: Port open but no data. Ensure finger is in.")
    except Exception as e:
        print(f"ERROR: {e}")
else:
    print(f"CRITICAL: {path} not found.")

# 2. Test Blood Pressure
print("\n[BLOOD PRESSURE TEST]")
# We found both hidraw0 and hidraw1, usually it's hidraw1 for CONTEC.
for path in ["/dev/hidraw1", "/dev/hidraw0"]:
    if os.path.exists(path):
        print(f"Testing {path}...")
        try:
            f = open(path, "rb")
            os.set_blocking(f.fileno(), False)
            time.sleep(1)
            data = f.read(64)
            f.close()
            if data:
                print(f"SUCCESS: Captured {len(data)} bytes of BP data.")
                print(f"HEX: {data.hex()}")
                break
            else:
                print(f"IDLE: {path} is open but silent.")
        except Exception as e:
            print(f"ERROR on {path}: {e}")
    else:
        print(f"SKIP: {path} not found.")

print("\n--- SNIFF COMPLETE ---")
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect(ip, username=username, password=password)
    with client.open_sftp().file('/home/kiosk/sniffer_rpi.py', 'w') as f:
        f.write(script_content)
    
    stdin, stdout, stderr = client.exec_command('python3 /home/kiosk/sniffer_rpi.py')
    print(stdout.read().decode())
    client.close()
except Exception as e:
    print(f"Error: {e}")
