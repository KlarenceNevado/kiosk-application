import paramiko
import sys
import time

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username=username, password=password, timeout=10)
print("Connected!\n")

# Step 1: Install ALL USB-serial drivers and restart USB
fix_cmd = """
echo "=== STEP 1: Install all USB-serial drivers ==="
echo '12345678' | sudo -S modprobe ch341 2>/dev/null; echo "ch341: $?"
echo '12345678' | sudo -S modprobe ftdi_sio 2>/dev/null; echo "ftdi_sio: $?"
echo '12345678' | sudo -S modprobe pl2303 2>/dev/null; echo "pl2303: $?"
echo '12345678' | sudo -S modprobe cdc_acm 2>/dev/null; echo "cdc_acm: $?"
echo '12345678' | sudo -S modprobe cp210x 2>/dev/null; echo "cp210x: $?"
echo '12345678' | sudo -S modprobe usbserial 2>/dev/null; echo "usbserial: $?"

echo ""
echo "=== STEP 2: Reset USB hub to force re-detection ==="
echo '12345678' | sudo -S sh -c 'echo 0 > /sys/bus/usb/devices/1-1.3/authorized' 2>/dev/null
sleep 2
echo '12345678' | sudo -S sh -c 'echo 1 > /sys/bus/usb/devices/1-1.3/authorized' 2>/dev/null
sleep 3

echo ""
echo "=== STEP 3: Check what appeared ==="
lsusb
echo ""
ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "Still only basic ports"
echo ""
lsmod | grep -i "serial\|ch341\|cp210\|ftdi\|pl2303\|cdc_acm"

echo ""
echo "=== STEP 4: Kill kiosk and check app serial port discovery ==="
pkill -f kiosk_application 2>/dev/null
sleep 1
cd /home/kiosk/kiosk_update/build/linux/arm64/release/bundle
export DISPLAY=:0
export XAUTHORITY=/home/kiosk/.Xauthority
timeout 15 ./kiosk_application 2>&1 | head -100 &
sleep 12
echo ""
echo "=== APP OUTPUT ==="
cat /tmp/kiosk.log 2>/dev/null | tail -30
echo ""
echo "=== DONE ==="
"""

stdin, stdout, stderr = client.exec_command(fix_cmd, get_pty=True, timeout=60)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
        sys.stdout.buffer.write(output.encode('utf-8'))
        sys.stdout.buffer.flush()
        if "[sudo] password" in output.lower():
            stdin.write(password + '\n')
            stdin.flush()
    time.sleep(0.5)

while stdout.channel.recv_ready():
    output = stdout.channel.recv(8192).decode('utf-8', errors='ignore')
    sys.stdout.buffer.write(output.encode('utf-8'))
    sys.stdout.buffer.flush()

print("\nExit:", stdout.channel.recv_exit_status())
client.close()
