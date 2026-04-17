#!/bin/bash
# Isla Verde Kiosk: Network + Deploy Setup for Raspberry Pi
# Run this script on the Pi to set a static IP and deploy the kiosk app.

export PATH="$PATH:/home/kiosk/flutter/bin"

echo "🌐 Skipping strict Netplan config to prevent routing conflicts with WiFi."
# The Pi will rely on DHCP or NetworkManager for the LAN connection.

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh
echo "✅ SSH enabled"

echo "🔐 Setting up serial port permissions..."
sudo usermod -a -G dialout pi 2>/dev/null || true
sudo usermod -a -G tty pi 2>/dev/null || true
sudo usermod -a -G dialout kiosk 2>/dev/null || true
sudo usermod -a -G tty kiosk 2>/dev/null || true
echo "✅ Serial access granted"

# Wait for network
sleep 3
echo "🔍 Testing connectivity..."
ping -c 1 192.168.137.1 && echo "✅ Can reach laptop!" || echo "❌ Cannot reach laptop"
ping -c 1 8.8.8.8 && echo "✅ Internet works!" || echo "⚠️ No internet (OK for local deploy)"

echo ""
echo ""
echo "📥 Skipping redundant git clone... Building from current directory."
cd "$(dirname "$0")/../.."

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
