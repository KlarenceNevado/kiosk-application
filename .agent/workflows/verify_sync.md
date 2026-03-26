---
description: Automated tool to check local and cloud consistency for critical tables.
---
1. **Run Full Sync Audit**:
// turbo
2. run_command: dart run scripts/sync_check.dart
3. **Verify Unsynced Details**:
// turbo
4. run_command: dart run scripts/find_unsynced.dart
7. **Verify Real-time Heartbeat**:
// turbo
8. run_command: tail -n 50 flutter_run_log.txt | grep "Realtime"
9. **Final Report**: Summarize the health of the synchronization system.
