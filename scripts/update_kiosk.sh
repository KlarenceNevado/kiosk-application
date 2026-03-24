#!/bin/bash

# Configuration
APP_NAME="kiosk_application"
VERSION_URL="https://klarencenevado.github.io/kiosk-application/version.json"
LOCAL_VERSION_FILE="version.txt"

echo "🚀 Starting Isla Verde Kiosk Launcher..."

# 1. Check for Internet
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "⚠️ No internet detected. Launching local version..."
    ./$APP_NAME
    exit 0
fi

# 2. Check for Updates
echo "🔍 Checking for updates..."
curl -s $VERSION_URL > remote_version.json
REMOTE_VERSION=$(grep -oP '(?<="version": ")[^"]*' remote_version.json)
LOCAL_VERSION=$(cat $LOCAL_VERSION_FILE 2>/dev/null || echo "0.0.0")

if [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "🆕 Update found! ($LOCAL_VERSION -> $REMOTE_VERSION)"
    KIOSK_URL=$(grep -oP '(?<="kiosk_linux_url": ")[^"]*' remote_version.json)
    
    echo "📥 Downloading update..."
    wget -q -O update.zip "$KIOSK_URL"
    
    echo "📦 Extracting update..."
    unzip -o update.zip -d .
    
    echo "$REMOTE_VERSION" > $LOCAL_VERSION_FILE
    rm update.zip remote_version.json
    echo "✅ Update complete!"
else
    echo "✨ Up to date ($LOCAL_VERSION)."
    rm remote_version.json
fi

# 3. Launch App
chmod +x $APP_NAME
./$APP_NAME
