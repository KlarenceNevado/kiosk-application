#!/bin/bash
# Isla Verde Kiosk: Network + Deploy Setup for Raspberry Pi
# Run this script on the Pi to set a static IP and deploy the kiosk app.

echo "🌐 Setting static IP on eth0..."
sudo tee /etc/netplan/99-kiosk-static.yaml > /dev/null << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.137.200/24
      routes:
        - to: default
          via: 192.168.137.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

sudo netplan apply
echo "✅ Static IP set to 192.168.137.200"

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh
echo "✅ SSH enabled"

echo "🔐 Setting up serial port permissions..."
sudo usermod -a -G dialout pi
sudo usermod -a -G tty pi
echo "✅ Serial access granted to 'pi' user"

# Wait for network
sleep 3
echo "🔍 Testing connectivity..."
ping -c 1 192.168.137.1 && echo "✅ Can reach laptop!" || echo "❌ Cannot reach laptop"
ping -c 1 8.8.8.8 && echo "✅ Internet works!" || echo "⚠️ No internet (OK for local deploy)"

echo ""
echo "📥 Cloning latest code..."
cd ~
rm -rf kiosk_app
git clone https://github.com/KlarenceNevado/kiosk-application.git kiosk_app || { echo "❌ Git clone failed. Check internet."; exit 1; }
cd kiosk_app

echo "🏗️ Installing dependencies..."
flutter pub get

echo "🏗️ Building release (this takes ~5 minutes on Pi)..."
flutter build linux --release

echo ""
echo "📦 Installing desktop shortcut..."
mkdir -p ~/Desktop
cp scripts/rpi/isla-kiosk.desktop ~/Desktop/
chmod +x ~/Desktop/isla-kiosk.desktop

echo ""
echo "🎬 Launching kiosk for test run..."
cd build/linux/arm64/release/bundle
./kiosk_application
