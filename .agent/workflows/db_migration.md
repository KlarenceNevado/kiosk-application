---
description: Standard procedure for upgrading the database schema.
---
1. Backup the current database file.
// turbo
2. run_command: cp "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db" "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db.bak"
3. Run the application or a test script to trigger the MigrationService.
4. Verify the new version in the database.
// turbo
5. run_command: sqlite3 "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db" "PRAGMA user_version;"
6. Check for the existence of newly added columns (e.g., report_url in vitals).
// turbo
7. run_command: sqlite3 "C:\Users\Klarence Nevado\AppData\Roaming\kiosk_application\kiosk_health.db" "PRAGMA table_info(vitals);" | grep report_url
