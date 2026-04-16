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
    client.connect(ip, username=username, password=password, timeout=10)
    print("Connected successfully!")
except Exception as e:
    print(f"Connection failed: {e}")
    sys.exit(1)

# Sequence of commands to fix routing and download everything
# 1. Force WiFi to be the default route if eth0 is blocking it
# 2. Cleanup and Clone
# 3. Run the setup script with the correct sudo pipe
commands = [
    "sudo ip route del default dev eth0 2>/dev/null || true",
    "rm -rf ~/kiosk_update",
    "echo \"--- Downloading Latest Code from GitHub ---\"",
    "git clone https://github.com/KlarenceNevado/kiosk-application.git ~/kiosk_update",
    "cd ~/kiosk_update/scripts/rpi && chmod +x setup_and_run.sh && echo '12345678' | sudo -S ./setup_and_run.sh"
]

full_cmd = " && ".join(commands)

print(f"Executing master setup...")
stdin, stdout, stderr = client.exec_command(full_cmd, get_pty=True)

# Read output in real-time
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
        # Filter emojis for windows terminal compatibility
        sys.stdout.buffer.write(output.encode('utf-8'))
        sys.stdout.buffer.flush()
        
        # Auto-fill any sudo password prompts
        if "[sudo] password" in output.lower():
            stdin.write(password + '\n')
            stdin.flush()

# Catch any trailing output
while stdout.channel.recv_ready():
    output = stdout.channel.recv(8192).decode('utf-8', errors='ignore')
    sys.stdout.buffer.write(output.encode('utf-8'))
    sys.stdout.buffer.flush()

print("\n\n--- MASTER DEPLOYMENT FINISHED ---")
print("Status Code:", stdout.channel.recv_exit_status())
client.close()
