import paramiko
import time
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

# Sequence of commands to run
commands = [
    "rm -rf ~/kiosk_update",
    "git clone https://github.com/KlarenceNevado/kiosk-application.git ~/kiosk_update",
    "cd ~/kiosk_update/scripts/rpi && chmod +x setup_and_run.sh && ./setup_and_run.sh"
]

# We need an interactive shell to handle sudo password prompts seamlessly
channel = client.invoke_shell()
time.sleep(1)
channel.recv(9999) # clear welcome message

for cmd in commands:
    print(f"\n--- Running: {cmd} ---")
    channel.send(cmd + '\n')
    
    # Wait for completion and handle prompts
    while True:
        time.sleep(0.5)
        if channel.recv_ready():
            output = channel.recv(4096).decode('utf-8', errors='ignore')
            sys.stdout.write(output)
            sys.stdout.flush()
            
            # If it prompts for a sudo password
            if "[sudo] password for pi:" in output.lower() or "password for pi:" in output.lower():
                channel.send(password + '\n')
            
            # Check if command has finished by looking for the prompt 
            # Note: The Pi prompt is usually 'pi@raspberrypi:~ $'
            # A more robust wait is difficult in async shell, but we can detect 'pi@' turning up
            # after our command echo.
        
        # Simple timeout / exit condition for this script:
        # If we see the flutter "Launching kiosk" or the command prompt `pi@` returning after output.
        if "pi@" in output and output.endswith("$ "):
            break
            
print("\n--- Update Complete ---")
client.close()
