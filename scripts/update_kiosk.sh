#!/bin/bash

# Configuration
APP_NAME="kiosk_application"
VERSION_URL="https://klarencenevado.github.io/kiosk-application/version.json"
LOCAL_VERSION_FILE="version.txt"
WORK_DIR="$HOME/isla-kiosk"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "🚀 Isla Verde Kiosk Launcher (Service Mode)"

# 1. Check for Internet
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "⚠️ No internet. Using local fallback..."
else
    # 2. Check for Updates
    echo "🔍 Checking registry..."
    curl -s --connect-timeout 5 $VERSION_URL > remote_version.json
    
    if [ $? -eq 0 ]; then
        REMOTE_VERSION=$(grep -oP '(?<="version": ")[^"]*' remote_version.json)
        LOCAL_VERSION=$(cat $LOCAL_VERSION_FILE 2>/dev/null || echo "0.0.0")

        if [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ] && [ ! -z "$REMOTE_VERSION" ]; then
            echo "🆕 Update found: $REMOTE_VERSION"
            KIOSK_URL=$(grep -oP '(?<="kiosk_linux_url": ")[^"]*' remote_version.json)
            
            echo "📥 Downloading..."
            wget -q -O update.zip "$KIOSK_URL"
            
            if [ $? -eq 0 ]; then
                echo "📦 Installing..."
                unzip -o update.zip -d .
                echo "$REMOTE_VERSION" > $LOCAL_VERSION_FILE
                echo "✅ Update successful."
            else
                echo "❌ Download failed."
            fi
            rm -f update.zip
        else
            echo "✨ Current version is up to date ($LOCAL_VERSION)."
        fi
        rm -f remote_version.json
    else
        echo "⚠️ Registry unreachable."
    fi
fi

# 3. Launch App
echo "🎬 Launching Kiosk..."
chmod +x $APP_NAME
# Run with necessary flags if any, and wait for process
./$APP_NAME
