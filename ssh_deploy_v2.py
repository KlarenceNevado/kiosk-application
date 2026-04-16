import paramiko
import sys

ip = '192.168.254.165'
username = 'pi'
password = '12345678'

print(f"Connecting to {username}@{ip}...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(ip, username=username, password=password, timeout=10)
    print("Connected successfully!")
except Exception as e:
    print(f"Connection failed: {e}")
    sys.exit(1)

cmd = "rm -rf ~/kiosk_update && git clone https://github.com/KlarenceNevado/kiosk-application.git ~/kiosk_update && cd ~/kiosk_update/scripts/rpi && chmod +x setup_and_run.sh && echo '12345678' | sudo -S ./setup_and_run.sh"

print(f"Executing: {cmd}")
stdin, stdout, stderr = client.exec_command(cmd, get_pty=True)

# Read output loop
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
        sys.stdout.write(output)
        sys.stdout.flush()
        if "[sudo] password for pi:" in output.lower():
            stdin.write(password + '\n')
            stdin.flush()

# Read remaining output
if stdout.channel.recv_ready():
    output = stdout.channel.recv(8192).decode('utf-8', errors='ignore')
    sys.stdout.write(output)
    sys.stdout.flush()

print("\nExit status:", stdout.channel.recv_exit_status())
client.close()
