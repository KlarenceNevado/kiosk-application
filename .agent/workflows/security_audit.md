---
description: Comprehensive security audit workflow for the Kiosk application system.
---

1. **Static Analysis & Dependencies**:
    - Run `flutter analyze` to catch potential coding issues.
    - Run `flutter pub outdated` to check for packages with security updates.
// turbo
2. run_command: flutter analyze > analysis_report.txt; flutter pub outdated > dependency_report.txt

3. **Secret Scanning**:
    - Search for hardcoded API keys, passwords, and sensitive strings.
// turbo
4. run_command: Get-ChildItem -Recurse lib | Select-String -Pattern "API_KEY|SECRET|PASSWORD|PRIVATE_KEY" > secrets_report.txt

5. **Data Security Audit**:
    - Verify sensitive data usage (PII) and ensure encryption where necessary.
    - Check for `flutter_secure_storage` implementation in `lib/core/services/`.
6. **Platform Configuration Audit**:
    - **Android**: Check `android/app/src/main/AndroidManifest.xml` for `android:allowBackup="false"` and `android:usesCleartextTraffic="false"`.
    - **iOS**: Check `ios/Runner/Info.plist` for `NSAppTransportSecurity` settings.
    - **Web**: Check `web/index.html` for basic CSP meta tags.
7. **Network Security Verification**:
    - Ensure all API endpoints in `lib/core/network/` or `lib/core/repositories/` use `https://`.
8. **Summary Report**:
    - Consolidate findings into `security_audit_summary.md` and notify the user.
