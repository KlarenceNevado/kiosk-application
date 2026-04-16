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
echo "=== 1. LIBSERIALPORT CHECK ==="
dpkg -l | grep -i serialport 2>/dev/null || echo "NOT INSTALLED VIA APT"
ldconfig -p | grep -i serialport 2>/dev/null || echo "NOT IN LIBRARY CACHE"
find / -name "libserialport*" -type f 2>/dev/null | head -5 || echo "NOT FOUND ON DISK"

echo ""
echo "=== 2. FULL LSUSB WITH VERBOSE ==="
lsusb -t

echo ""
echo "=== 3. ALL /dev/tty* DEVICES ==="
ls -la /dev/tty[A-Z]* 2>/dev/null

echo ""
echo "=== 4. KERNEL MODULES FOR USB-SERIAL ==="
lsmod | grep -i "serial\|ch341\|cp210\|ftdi\|pl2303\|cdc_acm"

echo ""
echo "=== 5. APP STDERR (journal) ==="
journalctl --user -n 30 --no-pager 2>/dev/null || echo "No user journal"

echo ""
echo "=== 6. SYSTEM JOURNAL FOR KIOSK ==="
journalctl -n 30 --no-pager -u '*kiosk*' 2>/dev/null || echo "No kiosk service journal"

echo ""  
echo "=== 7. DMESG ERRORS ==="
dmesg | grep -i "error\|fail\|serial\|tty" | tail -15

echo ""
echo "=== 8. FLUTTER LIBSERIALPORT BUNDLE ==="
find /home/kiosk/kiosk_update/build -name "*.so" | grep -i serial 2>/dev/null || echo "NO SERIAL .so IN BUILD"
ls -la /home/kiosk/kiosk_update/build/linux/arm64/release/bundle/lib/ | grep -i serial 2>/dev/null || echo "NOTHING"

echo ""
echo "=== DONE ==="
"""

stdin, stdout, stderr = client.exec_command(diag_cmd, get_pty=True)
output = stdout.read().decode('utf-8', errors='ignore')
sys.stdout.buffer.write(output.encode('utf-8'))
sys.stdout.buffer.flush()
client.close()
