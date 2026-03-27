---
description: Comprehensive end-to-end data sync diagnostic between Admin, Mobile, and PWA — covering patients, vitals, announcements, alerts, schedules, and chat.
---

# ═══════════════════════════════════════════════
# LAYER 1: AUTOMATED LOCAL DATABASE DIAGNOSTIC
# ═══════════════════════════════════════════════

1. **Run the Sync Diagnostic Script**:
    - Queries ALL 6 tables (patients, vitals, announcements, alerts, schedules, chat_messages).
    - Reports: unsynced counts, stuck soft-deletes, stale records (>24h), blocked records, totals.
// turbo
2. run_command: dart run scripts/sync_diagnostic.dart

# ═══════════════════════════════════════════════
# LAYER 2: LOCAL vs CLOUD COMPARISON
# ═══════════════════════════════════════════════

3. **Compare Local vs Supabase Cloud**:
    - Use the totals from Step 2 and compare against the Supabase Dashboard row counts.
    - If cloud count < local → push is failing for some records.
    - If cloud count > local → pull is not fetching all cloud data.
    - Check the Supabase Dashboard → Table Editor for each of: `patients`, `vitals`, `announcements`, `alerts`, `schedules`, `chat_messages`.

# ═══════════════════════════════════════════════
# LAYER 3: DELTA SYNC TIMESTAMP AUDIT
# ═══════════════════════════════════════════════

4. **Last Sync Timestamps**:
    - Inspect `SharedPreferences` for `last_sync_*` keys to see when each table was last synced.
    - A very old timestamp means the pull loop for that entity may be stuck.
5. **Verify `_updateLastSync` in code**: Confirm each handler updates its timestamp AFTER a successful pull:
    - [patient_sync_handler.dart](file:///c:/KioskApplication/kiosk_application/lib/core/services/database/sync/patient_sync_handler.dart) — Line 82
    - [vitals_sync_handler.dart](file:///c:/KioskApplication/kiosk_application/lib/core/services/database/sync/vitals_sync_handler.dart) — Line 89
    - [system_sync_handler.dart](file:///c:/KioskApplication/kiosk_application/lib/core/services/database/sync/system_sync_handler.dart) — Lines 94, 144, 194
    - [chat_sync_handler.dart](file:///c:/KioskApplication/kiosk_application/lib/core/services/database/sync/chat_sync_handler.dart) — Line 97

# ═══════════════════════════════════════════════
# LAYER 4: REAL-TIME SUBSCRIPTION AUDIT
# ═══════════════════════════════════════════════

6. **Verify Real-time Channel Registration**:
    - `SystemSyncHandler.subscribeAll()` → subscribes to `announcements`, `alerts`, `schedules`.
    - `PatientSyncHandler.subscribe()` → subscribes to `patients`.
    - `VitalsSyncHandler.subscribe()` → subscribes to `vitals`.
    - `ChatSyncHandler.subscribe()` → subscribes to `chat_messages`.
7. **Verify `startSyncLoop` Activates All Channels**:
    - [sync_service.dart](file:///c:/KioskApplication/kiosk_application/lib/core/services/database/sync_service.dart) Line 56-68.
8. **Supabase Realtime Policy Check**:
    - Ensure Supabase Realtime is enabled for ALL six tables in Supabase Dashboard → Database → Replication.
    - Missing tables in the replication list will NOT trigger real-time events.

# ═══════════════════════════════════════════════
# LAYER 5: ENTITY-BY-ENTITY CRUD VALIDATION
# ═══════════════════════════════════════════════

9. **Patients (Admin ↔ Kiosk)**:
    - Kiosk registers patient → appears in Supabase AND Admin dashboard.
    - Admin edits patient → syncs back to Kiosk local DB.
    - Admin deactivates (`is_deleted = 1`) → Kiosk hides the patient.
    - Edge case: `local_` prefixed IDs skip Supabase push (PatientSyncHandler Line 129).
10. **Vitals (Kiosk → Admin/Mobile)**:
    - Kiosk records vitals → encrypted data reaches Supabase.
    - Mobile patient views history → decrypted vitals match original.
    - Admin validates/adds remarks → `status` and `remarks` sync back.
11. **Announcements (Admin → Mobile/PWA)**:
    - Admin creates → appears in local DB AND Supabase.
    - Admin edits → `updated_at` changes, `is_synced` resets to 0 then syncs to 1.
    - Admin deletes → `is_deleted = 1` locally AND `true` in cloud; mobile hides item.
    - Mobile reacts → `reactions` JSON updates locally AND syncs to cloud.
12. **Alerts (Admin → Mobile/PWA)**:
    - Admin creates emergency alert → appears on patient devices in real-time.
    - Admin soft-deletes → mobile hides the alert.
    - Confirm `target_group` filtering (ALL, SENIORS, CHILDREN) works.
13. **Schedules (Admin → Mobile/PWA)**:
    - Admin creates schedule → appears on patient calendar.
    - Admin modifies date/location → update appears after next sync cycle.
    - Admin deletes → `is_deleted` propagation to mobile calendar.
14. **Chat Messages (Admin ↔ Mobile)**:
    - Admin sends message → appears on patient inbox (encrypted in cloud, decrypted locally).
    - Patient replies → Admin receives it.
    - Verify E2EE: cloud `content` column should show ciphertext, not plaintext.
    - Check `reactions`, `reply_to`, `media_url` sync correctly.

# ═══════════════════════════════════════════════
# LAYER 6: CONSOLIDATED REPORT
# ═══════════════════════════════════════════════

15. **Summarize all findings** from Layers 1-5 into `sync_test_report.md`.
    - Flag any entity with unsynced > 0 as ⚠️.
    - Flag any blocked records as 🚫.
    - Flag any stale timestamps as ⏳.
    - Provide specific file links and line numbers for any code-level issues found.
