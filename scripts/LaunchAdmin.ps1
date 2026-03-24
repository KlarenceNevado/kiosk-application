# Isla Verde Admin Launcher (Windows)
# This script keeps your Admin Desktop app updated automatically.

$AppName = "admin_desktop.exe"
$VersionUrl = "https://klarencenevado.github.io/kiosk-application/version.json"
$LocalVersionFile = "version.txt"

Write-Host "🚀 Starting Isla Verde Admin Launcher..." -ForegroundColor Green

# 1. Fetch Remote Version
try {
    $VersionData = Invoke-RestMethod -Uri $VersionUrl
    $RemoteVersion = $VersionData.version
    $RemoteUrl = $VersionData.admin_windows_url
} catch {
    Write-Host "⚠️ Could not check for updates. Launching local version..." -ForegroundColor Yellow
    if (Test-Path $AppName) {
        Start-Process $AppName
    } else {
        Write-Host "❌ Error: App not found. Please check your installation." -ForegroundColor Red
        Pause
    }
    exit
}

# 2. Check Local Version
if (Test-Path $LocalVersionFile) {
    $LocalVersion = Get-Content $LocalVersionFile
} else {
    $LocalVersion = "0.0.0"
}

# 3. Compare and Update
if ($RemoteVersion -ne $LocalVersion) {
    Write-Host "🆕 Update found! ($LocalVersion -> $RemoteVersion)" -ForegroundColor Cyan
    Write-Host "📥 Downloading update..." -ForegroundColor Gray
    
    try {
        Invoke-WebRequest -Uri $RemoteUrl -OutFile "update.zip"
        
        Write-Host "📦 Extracting update..." -ForegroundColor Gray
        # Ensure the app isn't running
        Stop-Process -Name "admin_desktop" -ErrorAction SilentlyContinue
        
        Expand-Archive -Path "update.zip" -DestinationPath "." -Force
        
        $RemoteVersion | Out-File -FilePath $LocalVersionFile -Encoding utf8
        Remove-Item "update.zip"
        Write-Host "✅ Update complete!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Update failed. Launching current version..." -ForegroundColor Red
    }
} else {
    Write-Host "✨ Up to date ($LocalVersion)." -ForegroundColor Green
}

# 4. Launch App
if (Test-Path $AppName) {
    Start-Process $AppName
} else {
    Write-Host "❌ Error: Launch failed. Binary missing." -ForegroundColor Red
    Pause
}
