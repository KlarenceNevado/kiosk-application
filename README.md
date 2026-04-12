# 🚀 Kiosk Health Application (v3.0 Pro)
> **Project #3 | Portfolio Showcase | Advanced Full-Stack Ecosystem**

[![Flutter CI](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev/)
[![Backend](https://img.shields.io/badge/Backend-Supabase-success)](https://supabase.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A mission-critical Health Kiosk ecosystem designed for community health monitoring in underserved areas. This professional-grade system integrates hardware sensors, real-time data synchronization, and a multi-platform frontend architecture to bridge the gap between physical vitals collection and digital health registry.

---

## 🏗️ Engineering Highlights (v3.0)
This ecosystem demonstrates complex software engineering and hardware integration:
- **Triple-Interface Architecture**: Decoupled modules for **Kiosk (Station)**, **Admin (Dashboard)**, and **Patient (Mobile/PWA)**.
- **Hardware Abstraction Layer (HAL)**: Unified logic for serial communication with Contec BP, CMS SPO2, and Weight Scale sensors.
- **Resilient Real-Time Sync**: Hybrid synchronization engine using RxDart Event Bus, SQLite local persistence, and Supabase Realtime.
- **Production-Ready CI/CD**: Fully automated release registry for Linux, Android, and Windows targets.
- **Security-First Design**: End-to-end encryption for medical data and role-based access control via Supabase Auth.

---

## 📌 Problem Statement
Community health monitoring often suffers from fragmented data, lack of hardware-specialized software, and poor connectivity in field deployments.
**The Solution:** An all-in-one ecosystem that captures vitals at a physical kiosk, syncs them to a secure cloud registry, and provides immediate access to both administrators (for triage) and patients (for personal health tracking).

---

## ✨ Key Features
- **Smart Sensing Engine**: Automatic discovery and data parsing for various medical sensors.
- **Real-Time Dashboards**: Instant monitoring of kiosk health and patient vitals for administrators.
- **Patient Health History**: Secured, cross-platform access to personal vitals with trend visualizations.
- **Automated Registry**: Seamless background synchronization that handles offline states and data parity checks.
- **Branded & Localized**: Built-in support for multiple languages and theme customization.

---

## 🛠️ Technical Stack
| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | Flutter 3.19+ | Uni-codebase for Linux, Windows, & Web |
| **Backend** | Supabase | PostgreSQL, Realtime, Auth, & Storage |
| **Persistence** | SQLite (Sqflite) | Local-first data architectural pattern |
| **Logic** | Provider / RxDart | State management and Reactive Event Bus |
| **Hardware** | LibSerialPort / ESP32 | Custom driver layer for sensor integration |

---

## 📐 Project Architecture
```mermaid
graph TD
    subgraph "Physical Kiosk (Pi/Linux)"
        A[Medical Sensors] -->|Serial/BLE| B[Sensor Hub Service]
        B -->|Event Bus| C[Kiosk App]
        C -->|SQLite| D[(Local Records)]
    end
    
    subgraph "Processing Layer"
        C -->|Sync Service| E[Supabase Backend]
        D -.->|Data Parity| E
    end
    
    subgraph "User Ecosystem"
        E --> F[Admin Dashboard]
        E --> G[Patient App (Mobile/PWA)]
        F -->|Broadcast| H[Announcements]
        G -->|Self-Service| I[Vitals History]
    end
```

---

## 📂 Project Structure
```text
kiosk_application/
├── assets/             # Global configurations, icons, and themes
├── lib/
│   ├── apps/           # Entry points for Kiosk, Admin, and Patient
│   ├── core/           # Shared services (Hardware, Sync, Security)
│   ├── features/       # Modular features (Health Check, Monitoring)
│   └── ui/             # Reusable UI components & Design System
├── scripts/            # Deployment and diagnostic utilities
├── supabase/           # Database migrations and schema definitions
└── test/               # Comprehensive Unit & Widget tests
```

---

## ⚡ Quick Start

### 1. Requirements
Ensure you have the Flutter SDK installed.
```bash
flutter --version
```

### 2. Setup
Clone the repository and install dependencies:
```bash
git clone https://github.com/KlarenceNevado/kiosk-application.git
cd kiosk_application
cp .env.template assets/.env
flutter pub get
```

### 3. Execution (Environment Flavors)
Run the specific application module:
```bash
# Kiosk Terminal
flutter run -t lib/main_kiosk.dart

# Admin Desktop
flutter run -t lib/main_admin.dart

# Patient Experience
flutter run -t lib/main_patient.dart
```

---

## 🤝 Author
Created by **Klarence Nevado**  
*System Architect & Developer specializing in HealthTech Ecosystems and Hardware Integration.*
