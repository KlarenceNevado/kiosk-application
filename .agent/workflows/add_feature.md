---
description: Standardized steps for adding a new feature/entity to the system.
---
1. **Define the Model**: Create a new class in `lib/features/[feature]/models/`.
2. **Create the DAO**: Inherit from `BaseDao` in `lib/core/services/database/dao/`.
3. **Register in DatabaseHelper**:
    - Add a `late final [New]Dao [new]Dao;` field.
    - Initialize it in `_initDB` after migrations.
4. **Create Sync Handler**: Inherit from `SyncHandler` in `lib/core/services/database/sync/`.
5. **Register in SyncService**:
    - Add a `late final [New]SyncHandler [new]Handler;` field.
    - Initialize it in `_internal()`.
    - Add it to `push()` and `pull()` lists in `_syncPendingRecords()`.
6. **Apply Migrations**: Update `MigrationService` version and add the new table schema.
7. **/analyze**: Run analysis to ensure all links are correct.
