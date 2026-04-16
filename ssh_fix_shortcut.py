import paramiko
import sys

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username=username, password=password, timeout=10)
print("Connected!")

# Fix the desktop shortcut directly on the Pi
fix_cmd = """
cat > ~/Desktop/isla-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Isla Verde Kiosk
Comment=Health Kiosk Application
Exec=/home/kiosk/kiosk_update/build/linux/arm64/release/bundle/kiosk_application
Icon=/home/kiosk/kiosk_update/assets/images/logo.png
Terminal=false
Categories=Medical;Health;
StartupNotify=true
X-GNOME-Autostart-enabled=true
EOF
chmod +x ~/Desktop/isla-kiosk.desktop
echo "SHORTCUT_FIXED"
"""

stdin, stdout, stderr = client.exec_command(fix_cmd, get_pty=True)
output = stdout.read().decode('utf-8', errors='ignore')
sys.stdout.buffer.write(output.encode('utf-8'))
sys.stdout.buffer.flush()
print("\nExit:", stdout.channel.recv_exit_status())
client.close()
