---
description: Audit the synchronization state of the local database tables.
---
1. Check patients table for unsynced records.
// turbo
2. run_command: sqlite3 -header -column "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db" "SELECT COUNT(*) FROM patients WHERE is_synced = 0;"
3. Check vitals table for unsynced records.
// turbo
4. run_command: sqlite3 -header -column "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db" "SELECT COUNT(*) FROM vitals WHERE is_synced = 0;"
5. Check system_logs for unsynced entries.
// turbo
6. run_command: sqlite3 -header -column "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db" "SELECT COUNT(*) FROM system_logs WHERE is_synced = 0;"
7. Summarize the sync health in a comment.
