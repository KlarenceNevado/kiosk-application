import paramiko
import sys
import time

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

print(f"Connecting to {username}@{ip}...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(ip, username=username, password=password, timeout=15)
    print("Connected! Rebooting Pi now...")
except Exception as e:
    print(f"Connection failed: {e}")
    sys.exit(1)

# Reboot the Pi
stdin, stdout, stderr = client.exec_command("echo '12345678' | sudo -S reboot", get_pty=True)
time.sleep(3)
client.close()
print("Reboot command sent. Waiting 60 seconds for Pi to come back online...")

# Wait for reboot
time.sleep(60)

# Reconnect and launch the app
print("Reconnecting...")
client2 = paramiko.SSHClient()
client2.set_missing_host_key_policy(paramiko.AutoAddPolicy())

for attempt in range(10):
    try:
        client2.connect(ip, username=username, password=password, timeout=10)
        print("Reconnected after reboot!")
        break
    except Exception:
        print(f"  Attempt {attempt+1}/10 - Pi not ready yet, waiting 10s...")
        time.sleep(10)
else:
    print("Could not reconnect. Pi may have a new IP after reboot.")
    sys.exit(1)

# Launch the kiosk app
launch_cmd = """
cd ~/kiosk_update/build/linux/arm64/release/bundle
export DISPLAY=:0
export XAUTHORITY=/home/kiosk/.Xauthority
chmod +x kiosk_application
nohup ./kiosk_application > /tmp/kiosk.log 2>&1 &
echo "KIOSK_LAUNCHED"
"""

print("Launching Kiosk Application...")
stdin, stdout, stderr = client2.exec_command(launch_cmd, get_pty=True)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
        sys.stdout.buffer.write(output.encode('utf-8'))
        sys.stdout.buffer.flush()

while stdout.channel.recv_ready():
    output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
    sys.stdout.buffer.write(output.encode('utf-8'))
    sys.stdout.buffer.flush()

print("\nDone! Check the Pi's screen — the Kiosk should be running.")
client2.close()
