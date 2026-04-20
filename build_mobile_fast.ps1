# Isla Verde Kiosk - Fast Mobile Build Automation
# This script builds the Patient App with full optimizations.

$projectDir = "C:\KioskApplication\kiosk_application"
Write-Host "🚀 Starting Optimized Android Build for Isla Verde Patient App..." -ForegroundColor Cyan

# Ensure we are in the right directory
Set-Location $projectDir

# 1. Clean up old build artifacts
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Gray
flutter clean

# 2. Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Gray
flutter pub get

# 3. Build optimized APK
Write-Host "🔨 Building Optimized Release APK (Tree-shaking enabled)..." -ForegroundColor Cyan
flutter build apk --release --tree-shake-icons --obfuscate --split-debug-info=build/app/outputs/symbols

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Build Successful!" -ForegroundColor Green
    Write-Host "📍 APK Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Build Failed. Please check the logs above." -ForegroundColor Red
    pause
}
