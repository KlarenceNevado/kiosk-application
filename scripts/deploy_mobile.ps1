# Isla Verde Kiosk - One-Command Deployment Automation
# This script handles versioning, optimized building, and metadata updates.

$projectDir = "C:\KioskApplication\kiosk_application"
$pubspecPath = "$projectDir\pubspec.yaml"
$versionJsonPath = "$projectDir\version.json"

Write-Host "🚀 Starting Global Deployment Automation..." -ForegroundColor Cyan

# 1. Increment Version in pubspec.yaml
Write-Host "🔢 Incrementing build number..." -ForegroundColor Gray
$content = Get-Content $pubspecPath
$newContent = $content | ForEach-Object {
    if ($_ -match "version: (\d+\.\d+\.\d+)\+(\d+)") {
        $version = $matches[1]
        $build = [int]$matches[2] + 1
        Write-Host "   New Version: $version+$build" -ForegroundColor Green
        "version: $version+$build"
    } else {
        $_
    }
}
$newContent | Set-Content $pubspecPath

# 2. Run Optimized Build
Write-Host "🔨 Building Optimized APK..." -ForegroundColor Cyan
Set-Location $projectDir
flutter build apk --release --tree-shake-icons

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit
}

# 3. Update version.json Metadata
$versionMatch = $newContent | Select-String "version: (\d+\.\d+\.\d+)\+(\d+)"
$versionStr = $versionMatch.Matches[0].Groups[1].Value + "+" + $versionMatch.Matches[0].Groups[2].Value

Write-Host "📝 Updating version.json..." -ForegroundColor Gray
$jsonObj = @{
    version = $versionStr
    last_updated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    platform = "android"
    apk_url = "https://klarencenevado.github.io/kiosk-application/app-release.apk"
}
$jsonObj | ConvertTo-Json | Set-Content $versionJsonPath

Write-Host "`n✨ Deployment Automation Complete!" -ForegroundColor Green
Write-Host "📍 Metadata ready at: version.json" -ForegroundColor Yellow
Write-Host "📍 APK ready at: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
