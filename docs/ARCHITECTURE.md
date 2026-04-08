# System Architecture

This document outlines the high-level data flow and interaction model between the hardware peripherals, the Kiosk Application, and the Supabase cloud backend.

## 🏗️ Technical Overview

The Kiosk System is built on a "Decentralized-First" architecture. Each physical station performs real-time processing and edge storage, synchronizing with the cloud only when connectivity is available.

### 🔄 Data Lifecycle Model

```mermaid
graph TD
    A[SENSORS: Oximeter/BP/Scale] -- Serial/BLE --> B[ESP32 SENSOR HUB]
    B -- UART/USB-Serial --> C[KIOSK APPLICATION (Linux/Pi)]
    C -- Local SQLite --> D[(Cloud Sync Event Bus)]
    D -- Realtime/TLS --> E[(SUPABASE CLOUD)]
    E -- WebSocket --> F[ADMIN DASHBOARD (Desktop)]
    E -- REST/PWA --> G[PATIENT APP (Android/PWA)]
```

### 🧩 Core Components

#### 1. Hardware Integration Layer (`lib/core/services/hardware/`)
- **SensorHubService**: Manages the lower-level UART/USB handshakes with the ESP32. It parses custom binary/hex protocols into clean JSON objects.
- **SensorManager**: High-level orchestrator that manages state transitions (Idle -> Measuring -> Transmitting -> Success).

#### 2. Persistence & Sync Layer (`lib/core/services/database/`)
- **DatabaseHelper**: Manages the local SQLite instance. It handles hardware-specific paths (e.g., NVMe SSD on Kiosk vs. Internal Storage on Android).
- **SyncService**: A background worker that maintains a 100% parity link with Supabase using periodic pulls and instant pushes.

#### 3. State Management (`lib/features/health_check/logic/`)
- **HealthWizardProvider**: A state machine that guides the user through measuring their Weight, Temperature, Oximetry, and Blood Pressure in a non-linear wizard.

## 📡 Connectivity Strategy

| Connectivity State | System Behavior |
| ------------------ | --------------- |
| **Connected**      | Instant high-priority push of vitals and heartbeat logging. |
| **Offline**        | Local buffering in encrypted SQLite; automatic replay upon recovery. |
| **Flaky**          | Low-bandwidth "Parity Pull" for announcements; deferral of heavy assets. |

## 🛠️ Performance Optimization

- **LogoGlow**: Uses `AnimatedBuilder` and `ScaleTransition` for 60fps UI performance even on low-power Raspberry Pi 4 models.
- **Database Hygiene**: Automated log rotation to the `/diagnostics` folder prevents disk-space issues during long-term deployment.
