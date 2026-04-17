import paramiko

ip = '192.168.254.165'
username = 'kiosk'
password = '12345678'

script_content = r'''
echo "12345678" | sudo -S sh -c 'echo "KERNEL==\"hidraw*\", SUBSYSTEM==\"hidraw\", MODE=\"0666\", GROUP=\"dialout\"" > /etc/udev/rules.d/99-hidraw.rules'
echo "12345678" | sudo -S udevadm control --reload-rules
echo "12345678" | sudo -S udevadm trigger
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect(ip, username=username, password=password)
    with client.open_sftp().file('/home/kiosk/fix_permissions.sh', 'w') as f:
        f.write(script_content)
    
    stdin, stdout, stderr = client.exec_command('bash /home/kiosk/fix_permissions.sh')
    print(stdout.read().decode())
    client.close()
except Exception as e:
    print(f"Error: {e}")
