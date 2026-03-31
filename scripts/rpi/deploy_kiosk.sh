#!/bin/bash

# Isla Verde Kiosk - Raspberry Pi 4B Deployment Helper
# Optimized for Raspberry Pi OS (Bookworm/Wayland)

echo "🚀 Starting Kiosk Deployment Setup..."

# 1. Serial Port Permissions
echo "🔐 Adding current user to 'dialout' group..."
sudo usermod -a -G dialout $USER

# 2. Dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y libserialport0 libsecret-1-0 libjson-cpp-dev

# 3. Raspberry Pi OS (Wayland) Optimizations
echo "🖥️ Configuring Wayfire for Kiosk..."
WAYFIRE_CONFIG="$HOME/.config/wayfire.ini"
mkdir -p "$(dirname "$WAYFIRE_CONFIG")"

if [ ! -f "$WAYFIRE_CONFIG" ]; then
    touch "$WAYFIRE_CONFIG"
fi

# Solar Efficiency: Set screen timeout to 10 minutes (600s) instead of indefinite (-1)
# This saves significant battery by allowing the 15.6" monitor to sleep when idle.
SCREEN_TIMEOUT=600 

if ! grep -q "\[idle\]" "$WAYFIRE_CONFIG"; then
    echo -e "\n[idle]\ndpms_timeout = $SCREEN_TIMEOUT\nscreensaver_timeout = $SCREEN_TIMEOUT" >> "$WAYFIRE_CONFIG"
else
    sed -i "/\[idle\]/,/\[/ s/dpms_timeout = .*/dpms_timeout = $SCREEN_TIMEOUT/" "$WAYFIRE_CONFIG"
    sed -i "/\[idle\]/,/\[/ s/screensaver_timeout = .*/screensaver_timeout = $SCREEN_TIMEOUT/" "$WAYFIRE_CONFIG"
fi

# 4. Solar/Power Optimizations
echo "🔋 Applying Solar-Efficiency Tweaks..."

# A. Set CPU Governor to 'ondemand' (Balance performance and power)
echo "cpufrequtils cpufrequtils/enable boolean true" | sudo debconf-set-selections
sudo apt install -y cpufrequtils
sudo bash -c "echo 'GOVERNOR=\"ondemand\"' > /etc/default/cpufrequtils"
sudo systemctl restart cpufrequtils

# B. (Optional) Disable Bluetooth to save ~50mA
# echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt

# 5. OS-Level Cursor Hiding (Fallback for Wayland)
echo "🖱️ Applying OS-level cursor hiding (rename method)..."
CURSOR_PATH="/usr/share/icons/PiXflat/cursors/left_ptr"
if [ -f "$CURSOR_PATH" ]; then
    sudo mv "$CURSOR_PATH" "${CURSOR_PATH}.bak" || echo "⚠️ Could not rename cursor (maybe already done?)"
fi

# 6. Kiosk Service (Auto-Start)
echo "⚙️ Creating Kiosk Systemd Service..."
SERVICE_PATH="/etc/systemd/system/isla_kiosk.service"
APP_PATH="$(pwd)/kiosk_application"

sudo bash -c "cat > $SERVICE_PATH" <<EOF
[Unit]
Description=Isla Verde Health Kiosk Application
After=network.target

[Service]
Type=simple
User=$USER
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
WorkingDirectory=$(pwd)
ExecStart=$APP_PATH
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo "✅ Setup complete. Please REBOOT to apply all changes."
echo "💡 To enable auto-start, run: sudo systemctl enable isla_kiosk"
