import paramiko
import sys

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username=username, password=password, timeout=10)
print("Connected!\n")

diag_cmd = """
echo "=== BLUETOOTH DEVICES ==="
bluetoothctl devices 2>/dev/null || echo "No bluetoothctl"
echo ""
echo "=== BLUETOOTH PAIRED ==="
bluetoothctl paired-devices 2>/dev/null || echo "No paired"
echo ""
echo "=== RFCOMM PORTS ==="
ls -la /dev/rfcomm* 2>/dev/null || echo "No rfcomm ports"
echo ""
echo "=== BLUETOOTH STATUS ==="
hciconfig 2>/dev/null || echo "No hciconfig"
echo ""
echo "=== ALL USB DEVICES DETAILED ==="
lsusb -v 2>/dev/null | grep -A3 "idVendor" | head -60
echo ""
echo "=== UNPLUG TEST: Unplug oximeter, wait 3s, then replug ==="
echo "Current ttyUSB count:"
ls /dev/ttyUSB* 2>/dev/null | wc -l
echo ""
echo "=== SerialPort available (from flutter_libserialport perspective) ==="
ls /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* /dev/rfcomm* 2>/dev/null
echo ""
echo "=== DONE ==="
"""

stdin, stdout, stderr = client.exec_command(diag_cmd, get_pty=True)
output = stdout.read().decode('utf-8', errors='ignore')
sys.stdout.buffer.write(output.encode('utf-8'))
sys.stdout.buffer.flush()
client.close()
