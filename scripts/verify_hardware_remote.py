import paramiko

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

script_content = r'''
import serial, time
def check(p, b, name):
    print(f"--- Checking {name} on {p} ---")
    try:
        ser = serial.Serial(p, b, timeout=2)
        time.sleep(1)
        line = ser.readline().decode('utf-8', errors='ignore').strip()
        if line:
            print(f"  [SUCCESS] {name} is alive: {line}")
        else:
            print(f"  [IDLE] {name} is connected but waiting for data.")
        ser.close()
    except Exception as e:
        print(f"  [MISSING] {name} not found: {e}")

print("\nISLA VERDE HARDWARE SCAN (4 SENSORS)")
print("====================================")
check('/dev/ttyUSB0', 115200, "Hub (Weight/Temp)")
check('/dev/ttyUSB1', 19200, "Contec (Oxi/BP)")
print("====================================\n")
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect(ip, username=username, password=password)
    # Write the file
    sftp = client.open_sftp()
    with sftp.file('/home/kiosk/hardware_check.py', 'w') as f:
        f.write(script_content)
    sftp.close()
    
    # Run the file
    stdin, stdout, stderr = client.exec_command('python3 /home/kiosk/hardware_check.py')
    print(stdout.read().decode())
    client.close()
except Exception as e:
    print(f"Error: {e}")
