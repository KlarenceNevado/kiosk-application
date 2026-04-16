import paramiko
import sys
import time

# Use WiFi IP for internet stability
ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

print(f"Connecting to {username}@{ip} via WiFi...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(ip, username=username, password=password, timeout=15)
    print("Connected successfully!")
except Exception as e:
    print(f"Connection failed: {e}")
    sys.exit(1)

# Sequence of commands to fix path and build everything
# Using 'bash -l -c' to ensure Flutter is in the PATH
commands = [
    "sudo ip route del default dev eth0 2>/dev/null || true",
    "cd ~/kiosk_update/scripts/rpi",
    "chmod +x setup_and_run.sh",
    "bash -l -c \"cd ~/kiosk_update/scripts/rpi && ./setup_and_run.sh\""
]

full_cmd = " && ".join(commands)

print(f"Executing master setup with Path fix...")
stdin, stdout, stderr = client.exec_command(full_cmd, get_pty=True)

# Read output in real-time
all_output = ""
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
        all_output += output
        # Print to PC console
        sys.stdout.buffer.write(output.encode('utf-8'))
        sys.stdout.buffer.flush()
        
        # Auto-fill any sudo password prompts
        if "[sudo] password" in output.lower() or "password for kiosk" in output.lower():
            # Use a slight delay to ensure the prompt is fully readable
            time.sleep(1)
            stdin.write(password + '\n')
            stdin.flush()

# Catch any trailing output
while stdout.channel.recv_ready():
    output = stdout.channel.recv(8192).decode('utf-8', errors='ignore')
    all_output += output
    sys.stdout.buffer.write(output.encode('utf-8'))
    sys.stdout.buffer.flush()

print("\n\n--- MASTER DEPLOYMENT FINISHED ---")
exit_status = stdout.channel.recv_exit_status()
print("Status Code:", exit_status)

if exit_status == 0:
    print("SUCCESS: Kiosk is updated and launching!")
else:
    print("NOTICE: Build finished. Check if app is launching on the Pi screen.")

client.close()
