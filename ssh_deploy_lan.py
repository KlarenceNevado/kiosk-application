import paramiko
import os
import sys

# Pi connection details
ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'
remote_path = '/home/kiosk/kiosk_update'

def upload_directory(sftp, local_dir, remote_dir):
    try:
        sftp.mkdir(remote_dir)
    except IOError:
        pass
    
    for item in os.listdir(local_dir):
        # Skip large/sensitive folders
        if item in ['.git', 'build', '.dart_tool', 'venv', '__pycache__', '.agent', '.gemini']:
            continue
            
        local_path = os.path.join(local_dir, item)
        remote_item_path = remote_dir + '/' + item
        
        if os.path.isfile(local_path):
            print(f"Uploading {item}...")
            sftp.put(local_path, remote_item_path)
        elif os.path.isdir(local_path):
            upload_directory(sftp, local_path, remote_item_path)

print(f"Connecting to {ip}...")
transport = paramiko.Transport((ip, 22))
transport.connect(username=username, password=password)
sftp = paramiko.SFTPClient.from_transport(transport)

print("Starting direct LAN transfer (bypassing GitHub)...")
local_root = os.getcwd()
upload_directory(sftp, local_root, remote_path)

print("Transfer complete! Now triggering build...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username=username, password=password)

build_cmd = f"""
export PATH="$HOME/flutter/bin:$PATH"
cd {remote_path}
flutter pub get
flutter build linux --release
sudo usermod -a -G dialout $USER
mkdir -p ~/Desktop
cp scripts/rpi/isla-kiosk.desktop ~/Desktop/
chmod +x ~/Desktop/isla-kiosk.desktop
echo "KIOSK_READY_REBOOT"
"""

stdin, stdout, stderr = client.exec_command(f"bash -c '{build_cmd}'", get_pty=True)
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        print(stdout.channel.recv(4096).decode('utf-8', errors='ignore'), end="")

transport.close()
client.close()
