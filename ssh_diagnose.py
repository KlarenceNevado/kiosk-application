import paramiko
import sys

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username=username, password=password, timeout=10)
print("Connected!\n")

# Run a comprehensive hardware diagnostic
diag_cmd = """
echo "=== 1. USB DEVICES ==="
lsusb

echo ""
echo "=== 2. SERIAL PORTS ==="
ls -la /dev/ttyUSB* /dev/ttyACM* /dev/ttyAMA* 2>/dev/null || echo "NO SERIAL PORTS FOUND"

echo ""
echo "=== 3. USER GROUPS (dialout check) ==="
groups

echo ""
echo "=== 4. SERIAL PORT PERMISSIONS ==="
stat -c '%a %U %G %n' /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "NO PORTS TO CHECK"

echo ""
echo "=== 5. APP LOGS (last 50 lines) ==="
cat /tmp/kiosk.log 2>/dev/null | tail -50 || echo "NO LOG FILE FOUND"

echo ""
echo "=== 6. DMESG USB (last 20 lines) ==="
dmesg | grep -i "usb\|tty\|serial\|ch341\|cp210\|ftdi" | tail -20

echo ""
echo "=== 7. RUNNING KIOSK PROCESSES ==="
ps aux | grep kiosk_application | grep -v grep

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
"""

stdin, stdout, stderr = client.exec_command(diag_cmd, get_pty=True)
output = stdout.read().decode('utf-8', errors='ignore')
sys.stdout.buffer.write(output.encode('utf-8'))
sys.stdout.buffer.flush()
client.close()
