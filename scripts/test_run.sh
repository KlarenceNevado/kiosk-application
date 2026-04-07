#!/bin/bash

# Isla Verde Kiosk: Manual Test Run Script
# Use this to verify code changes before finalizing service deployment.

echo "🚀 Starting Kiosk Test Run..."

# 1. Pull Latest
echo "📥 Checking for latest code..."
git pull origin master

# 2. Build for Release (ARM64)
echo "🏗️ Building Linux Release (this may take a few minutes)..."
flutter build linux --release

# 3. Launch the Application
echo "🎬 Launching..."
cd build/linux/arm64/release/bundle
./kiosk_application
