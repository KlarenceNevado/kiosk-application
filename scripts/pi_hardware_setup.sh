#!/bin/bash

#岛 Isla Verde Kiosk - Hardware Permission Setup
# This script configures the Raspberry Pi for hardware sensor access.

echo "🛠️ Island Verde Kiosk: Starting Hardware Setup..."

# 1. Add current user to required groups
echo "👥 Adding user $USER to dialout and tty groups..."
sudo usermod -a -G dialout $USER
sudo usermod -a -G tty $USER

# 2. Setup udev Rules for constant device names (Optional but recommended)
echo "📝 Creating udev rules for sensors..."
sudo bash -c 'cat <<EOF > /etc/udev/rules.d/99-medical-sensors.rules
# ESP32 Hub
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="kiosk_hub", MODE="0666"
# generic CH340 serial for some medical devices
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="medical_serial_%n", MODE="0666"
EOF'

# 3. Reload udev rules
echo "🔄 Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# 4. Open current ttyUSB devices for writing
echo "🔓 Granting immediate read/write access to existing USB ports..."
sudo chmod 666 /dev/ttyUSB* 2>/dev/null || echo "⚠️ No /dev/ttyUSB devices found yet."
sudo chmod 666 /dev/ttyACM* 2>/dev/null || echo "⚠️ No /dev/ttyACM devices found yet."

echo "✅ Hardware Setup Complete!"
echo "⚠️ IMPORTANT: You MUST REBOOT the Raspberry Pi for group changes to take effect."
