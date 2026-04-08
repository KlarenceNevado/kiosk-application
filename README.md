# Kiosk Health Application

[![Dart CI](https://github.com/KlarenceNevado/kiosk-application/actions/workflows/ci.yml/badge.svg)](https://github.com/KlarenceNevado/kiosk-application/actions/workflows/ci.yml)
[![Release](https://github.com/KlarenceNevado/kiosk-application/actions/workflows/release.yml/badge.svg)](https://github.com/KlarenceNevado/kiosk-application/actions/workflows/release.yml)

A robust, multi-platform Health Kiosk ecosystem designed for community health monitoring. This system integrates hardware sensors, a central data hub, and patient-facing applications to streamline vital sign collection and monitoring.

## 🚀 Ecosystem Overview

- **Kiosk Application (Linux/Pi)**: The primary interface for physical health stations, optimized for Raspberry Pi with hardware sensor integration.
- **Admin Dashboard (Desktop)**: A management tool for healthcare providers to monitor stations and manage announcements.
- **Patient Application (Android/PWA)**: A cross-platform mobile app for patients to view their health history and receive notifications.

## 🛠️ Tech Stack

- **Frontend**: Flutter (3.19+)
- **Backend & Database**: Supabase (PostgreSQL, Realtime, Auth, Storage)
- **Hardware Integration**: Custom ESP32 Sensor Hub, Serial Port communication.
- **Infrastructure**: Raspberry Pi 4B/5 with NVMe SSD support.

## 📋 Getting Started

### Prerequisites

- Flutter SDK (stable)
- Supabase account and project
- Hardware sensors (optional for development)

### Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/KlarenceNevado/kiosk-application.git
   cd kiosk_application
   ```
2. Create `assets/.env` based on `.env.template`:
   ```bash
   cp .env.template assets/.env
   # Add your SUPABASE_URL and SUPABASE_ANON_KEY
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```

## 🔌 Hardware Integration

The kiosk supports various peripherals via a custom Sensor Hub:
- **Thermal Printer**: For instant health record printouts.
- **Oximeter**:cms50d-bt protocol support.
- **Blood Pressure Monitor**: CONTEC 08A integration.
- **ECG/Weight Scale**: Dynamic discovery via ESP32.

### Pi Deployment

To setup a new Raspberry Pi station, a one-shot setup script is available:
```bash
./scripts/pi_setup_final.sh
```

## 🧪 Development & Testing

- **Run Kiosk**: `flutter run -t lib/main_kiosk.dart`
- **Run Patient App**: `flutter run -t lib/main_patient.dart`
- **Run Admin**: `flutter run -t lib/main_admin.dart`
- **Analytic Scripts**: `scripts/sync_diagnostic.dart` for checking data parity.

## 🛡️ Security

We take security seriously. Please refer to [SECURITY.md](SECURITY.md) for vulnerability reporting and security policies.

---
Built with ❤️ by [Klarence Nevado](https://github.com/KlarenceNevado)
