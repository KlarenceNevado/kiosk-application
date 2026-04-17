import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.254.165', username='kiosk', password='12345678')
stdin, stdout, stderr = client.exec_command('cd kiosk-app && git pull origin master')
print(stdout.read().decode())
client.close()
