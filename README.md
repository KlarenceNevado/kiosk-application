# 🛡️ Community-Centered Healthcare IoT Ecosystem (v3.0 Pro)
> **Final Capstone Showcase | Project #3 | System Architecture & IoT Integration**

[![Flutter Version](https://img.shields.io/badge/Flutter-3.19.x-blue.svg?style=for-the-badge&logo=flutter)](https://flutter.dev/)
[![Backend Architecture](https://img.shields.io/badge/Backend-Supabase_Realtime-success?style=for-the-badge&logo=supabase)](https://supabase.com/)
[![System Stability](https://img.shields.io/badge/Build-Production_Ready-orange?style=for-the-badge)](https://github.com/)

An advanced, multi-tier health monitoring ecosystem engineered to optimize community healthcare delivery. This project serves as a comprehensive "Field-to-Cloud" solution, integrating custom hardware drivers, resilient data synchronization, and a decoupled multi-app frontend designed for mission-critical health triage.

---

## 📄 Abstract
In underserved and rural communities, the lack of centralized, real-time health data often leads to delayed medical intervention and fragmented patient care. This project implements a **Community-Centered Healthcare IoT Ecosystem** that bridges the gap between physical vitals collection and digital healthcare management. By utilizing a high-resiliency synchronization engine and a Hardware Abstraction Layer (HAL), the system ensures that medical data is captured, secured, and distributed to healthcare providers and patients with zero-latency overhead.

---

## 🏗️ Engineering & Conceptual Highlights
This system demonstrates mastery in modern software engineering and IoT integration:
- **Resilient Edge Computing**: Optimized for Raspberry Pi 4B/5, utilizing local SQLite persistence to ensure 100% data availability even during network partitions.
- **Hardware Abstraction Layer (HAL)**: A unified driver architecture (Serial over USB/BLE) that standardizes data ingestion from varied medical peripherals (Contec, CMS, etc.).
- **Uni-Codebase Scalability**: A shared Dart logic layer that powers three distinct user experiences: Kiosk Station, Admin Dashboard, and Patient Mobile/PWA.
- **Reactive Stream Architecture**: Leverages RxDart and Provider for high-performance, event-driven UI updates across the entire ecosystem.

---

## 📐 Conceptual Framework (System Architecture)
The ecosystem follows a **Tiered IoT Architecture** (Edge | Cloud | End-User) to ensure scalability and data integrity.

```mermaid
graph TD
    subgraph "Tier 1: Edge Layer (Physical Kiosk)"
        A[Medical Peripherals] -->|Serial/RS232| B["Sensor Hub (HAL)"]
        B -->|Encapsulated Events| C[Kiosk Interface]
        C -->|SQLite| D[(Local Persistence)]
    end
    
    subgraph "Tier 2: Cloud Layer (Data Hub)"
        C -->|Resilient Sync Service| E[Supabase Cloud]
        D -.-.->|Data Parity Check| E
    end
    
    subgraph "Tier 3: End-User Ecosystem"
        E --> F["Admin Dashboard (Desktop)"]
        E --> G["Patient Portal (Mobile/PWA)"]
        F -->|Global Broadcast| H[Announcements]
        G -->|Self-Service| I[Vitals History]
    end
    
    style E fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#bbf,stroke:#333,stroke-width:2px
```

---

## 🛠️ System Methodology
The development of this ecosystem followed a **Hardware-Software Co-Design** approach:
1.  **Hardware Analysis**: Reverse-engineering serial protocols for varied medical sensors to build a standardized parser.
2.  **Infrastructure Orchestration**: Implementing a Supabase-backed real-time database to handle concurrent vitals streams from multiple kiosk stations.
3.  **User-Centric Design**: Building tailored interfaces for different personas (Nurses, Patients, and Administrators) to reduce cognitive load during health checks.

---

## 📊 Technical Specifications

### Hardware Specifications
| Component | Specification | Purpose |
| :--- | :--- | :--- |
| **Primary Unit** | Raspberry Pi 4B (4GB/8GB) | Edge computing and station hosting |
| **Sensor Hub** | ESP32-WROOM-32 | Microcontroller orchestration for local sensors |
| **Connectivity** | Wi-Fi 2.4/5GHz / Ethernet | Field-to-Cloud communication |
| **Peripherals** | Contec BP, CMS SPO2, Scale | Validated medical-grade data ingestion |

### Software Specifications
| Category | Technology | Implementation Detail |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.19.x | High-performance multi-platform UI |
| **BaaS** | Supabase | PostgreSQL, Auth, Realtime, & Storage |
| **State Mgmt** | RxDart / Provider | Reactive data flows and decoupled state |
| **Deployment** | GitHub Actions | Automated build registry and versioning |

---

## 🛡️ Security & Data Integrity
Ensuring the privacy of medical data is paramount to the project's success:
- **At-Rest Encryption**: Sensitive vitals data is encrypted locally before being committed to the SQLite database.
- **Auth Layer**: JWT-based authentication via Supabase Auth ensures that only authorized personnel can access the Admin Dashboard.
- **Sync Parity**: A background synchronization manager monitors the state of every local record, ensuring eventual consistency with the cloud database even after extended offline periods.

---

## 📂 Project Decomposition
```text
kiosk_location/
├── assets/             # Branded typography, Lottie animations, and global .env
├── lib/
│   ├── apps/           # Triple-Head entry points (Kiosk, Admin, Patient)
│   ├── core/           # The "Brain" (HAL, SyncService, Security, Network)
│   ├── features/       # Business logic (Triage, History, Chat, Health Check)
│   └── ui/             # High-fidelity Design System (Widgets, Themes)
├── scripts/            # Field deployment and system diagnostic tools (RPi Setup)
├── supabase/           # PostgreSQL migrations and real-time security policies
└── test/               # Unit, Widget, and End-to-End integration tests
```

---

## ⚡ Field Deployment Implementation

### 1. Environment Configuration
Initialize the local environment from the registry template:
```bash
git clone https://github.com/KlarenceNevado/kiosk-application.git
cd kiosk_application
cp .env.template assets/.env
flutter pub get
```

### 2. Kiosk Flavor Selection
Compile and execute the specific ecosystem module:
```bash
# Production Kiosk Station (Linux/RPI)
flutter run -t lib/main_kiosk.dart

# Medical Admin Dashboard (Desktop)
flutter run -t lib/main_admin.dart

# Patient Experience (Android/Web)
flutter run -t lib/main_patient.dart
```

---

## 🚀 Future Roadmap
- **AI-Powered Triage**: Implementing local On-Device ML for early warning sign detection.
- **Telemedicine Handover**: Direct video-call integration between Kiosk and remote doctors.
- **Solar Eco-Mode**: Optimization for off-grid operations in solar-powered stations.

---

## 🤝 Acknowledgments
*   **System Architect**: [Klarence Nevado](https://github.com/KlarenceNevado)
*   **Domain Expertise**: HealthTech IoT & Resilient Systems Engineering.

---
"Empowering communities through accessible, resilient, and data-driven healthcare."
