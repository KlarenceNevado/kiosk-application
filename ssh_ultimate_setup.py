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
# We will hunt for flutter in common locations if it's not in PATH
setup_script = """
# 1. Fix Routing
sudo ip route del default dev eth0 2>/dev/null || true
echo "✅ Routing fixed (WiFi preferred)"

# 2. Find Flutter
FLUTTER_PATH=""
for p in "$HOME/flutter/bin/flutter" "$HOME/development/flutter/bin/flutter" "/snap/bin/flutter" "/usr/bin/flutter"; do
    if [ -f "$p" ]; then
        FLUTTER_PATH="$p"
        break
    fi
done

if [ -z "$FLUTTER_PATH" ]; then
    # Final attempt: search
    FLUTTER_PATH=$(find ~ -name flutter -type f -executable | grep bin/flutter | head -n 1)
fi

if [ -z "$FLUTTER_PATH" ]; then
    echo "❌ FATAL: Flutter binary not found!"
    exit 1
fi

echo "✅ Found Flutter at: $FLUTTER_PATH"
FLUTTER_ROOT=$(dirname $(dirname "$FLUTTER_PATH"))
export PATH="$FLUTTER_ROOT/bin:$PATH"

# 3. Clean and Clone
rm -rf ~/kiosk_update
echo "📥 Downloading latest code..."
git clone https://github.com/KlarenceNevado/kiosk-application.git ~/kiosk_update

# 4. Build
cd ~/kiosk_update
echo "🏗️  Installing dependencies..."
$FLUTTER_PATH pub get

echo "🏗️  Building release (5 mins)..."
$FLUTTER_PATH build linux --release

# 5. Permissions
echo "🔐 Setting up serial port permissions..."
sudo usermod -a -G dialout $USER
sudo usermod -a -G tty $USER

# 6. Shortcut
echo "📦 Installing desktop shortcut..."
mkdir -p ~/Desktop
cp scripts/rpi/isla-kiosk.desktop ~/Desktop/
chmod +x ~/Desktop/isla-kiosk.desktop

echo "✨ REPO BUILD COMPLETE. Please REBOOT the Pi now."
"""

print(f"Executing Ultimate Setup...")
stdin, stdout, stderr = client.exec_command(f"bash -c '{setup_script}'", get_pty=True)

# Read output in real-time
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        output = stdout.channel.recv(4096).decode('utf-8', errors='ignore')
        # Print to PC console
        sys.stdout.buffer.write(output.encode('utf-8'))
        sys.stdout.buffer.flush()
        
        # Auto-fill any sudo password prompts
        if "[sudo] password" in output.lower() or "password for kiosk" in output.lower():
            time.sleep(1)
            stdin.write(password + '\n')
            stdin.flush()

# Catch any trailing output
while stdout.channel.recv_ready():
    output = stdout.channel.recv(8192).decode('utf-8', errors='ignore')
    sys.stdout.buffer.write(output.encode('utf-8'))
    sys.stdout.buffer.flush()

print("\n\n--- ULTIMATE DEPLOYMENT FINISHED ---")
print("Status Code:", stdout.channel.recv_exit_status())
client.close()
