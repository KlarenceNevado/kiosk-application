#!/bin/bash
# Run this script ON the Raspberry Pi 5 to install Flutter and build the Kiosk app.
# Prerequisites: Pi must be connected to the internet.

set -e

echo "=== Raspberry Pi 5 Flutter Kiosk Build Script ==="

# 1. Install dependencies
echo "[1/5] Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils cmake ninja-build pkg-config \
  libgtk-3-dev libblkid-dev liblzma-dev clang

# 2. Install Flutter (if not already installed)
if ! command -v flutter &>/dev/null; then
  echo "[2/5] Installing Flutter..."
  cd ~
  git clone https://github.com/flutter/flutter.git -b stable
  export PATH="$HOME/flutter/bin:$PATH"
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
  flutter precache --linux
else
  echo "[2/5] Flutter already installed. Updating..."
  flutter upgrade
fi

# 3. Enable Linux desktop support
echo "[3/5] Enabling Flutter Linux desktop..."
flutter config --enable-linux-desktop

# 4. Copy the project files (assumes you have scp'd the project here)
# Adjust path if needed:
PROJECT_DIR="$HOME/kiosk_application"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "ERROR: Project directory not found at $PROJECT_DIR"
  echo "Please copy the project first using:"
  echo "  scp -r /path/to/kiosk_application pi@<PI_IP>:~/kiosk_application"
  exit 1
fi

cd "$PROJECT_DIR"

# 5. Get dependencies and build
echo "[4/5] Getting dependencies..."
flutter pub get

echo "[5/5] Building Kiosk app for Linux..."
flutter build linux -t lib/main_kiosk.dart --release

echo ""
echo "=== BUILD COMPLETE ==="
echo "Output is at: $PROJECT_DIR/build/linux/arm64/release/bundle/"
echo "Run the app with: ./build/linux/arm64/release/bundle/kiosk_application"
