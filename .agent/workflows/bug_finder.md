---
description: Comprehensive diagnostic workflow to identify and debug issues across UI, Frontend, Backend, Database, and System Connections.
---

1. **UI & Frontend Diagnostic**:
    - Run Static Analysis to catch linting/type errors.
    - Search for potential layout overflows (`RenderFlex`).
    - Check for missing localizations (`AppLocalizations`).
// turbo
2. run_command: flutter analyze > analysis_report.txt; Get-ChildItem -Recurse lib | Select-String -Pattern "RenderFlex|overflow" > ui_issues.txt

3. **Backend & Logic Audit**:
    - Audit service classes for unhandled exceptions or empty catch blocks.
    - Verify the initialization sequence in `InitializationService`.
// turbo
4. run_command: Get-ChildItem -Recurse lib/core/services | Select-String -Pattern "catch (e) {}" > logic_audit.txt

5. **Database & Sync Audit**:
    - Verify all DAOs are correctly registered in `DatabaseHelper`.
    - Check for missing `SyncHandler` implementations in `SyncService`.
    - Audit local database schema vs DAO models.
6. **System Connection Audit**:
    - Check `FlavorConfig` and `.env` (if any) for environment consistency.
    - Verify that all necessary repositories are registered in the Dependency Injection (DI) layer or singleton registry.
7. **Consolidated Bug Report**:
    - Review all generated `.txt` reports.
    - Summarize findings into `bug_finder_summary.md`.
    - Provide specific file links and line numbers for identified issues.
