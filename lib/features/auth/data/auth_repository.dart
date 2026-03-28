import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/database/database_helper.dart';
import '../../../core/services/database/sync_service.dart';
import '../../../core/services/system/sync_event_bus.dart';
import '../../../core/services/security/encryption_service.dart';
import '../../../core/services/system/app_environment.dart';
import '../models/user_model.dart';
import '../../../core/services/notifications/chat_listener_service.dart';
import '../../../core/services/notifications/system_alert_listener_service.dart';
import '../../../core/services/notifications/vitals_listener_service.dart';
import '../../../core/services/notifications/announcement_listener_service.dart';
import '../../../core/services/security/notification_service.dart';
import '../../../core/services/security/security_logger.dart';
import '../../../core/services/system/system_log_service.dart';
import '../domain/i_auth_repository.dart';

class LocalAuthRepository extends ChangeNotifier implements IAuthRepository {
  User? _currentUser;
  List<User> _users = [];
  bool _isLoading = false;
  bool _isRefreshing = false; // NEW: Prevent concurrent refreshes
  StreamSubscription? _patientSyncSub;
  Timer? _refreshDebounce; // NEW: Debounce multiple sync events

  // STORAGE KEYS
  static const String _migrationKey = 'sqlite_migration_done';
  static const String _storageKey = 'secure_kiosk_users';

  @override
  User? get currentUser => _currentUser;
  @override
  List<User> get users => _users;
  @override
  bool get isLoading => _isLoading;
  @override
  Future<void> get initialization => Future.value();

  LocalAuthRepository() {
    _loadUsers();

    // Listen for cloud changes and refresh local list (Debounced to avoid lag)
    _patientSyncSub = SyncEventBus.instance.patientStream.listen((_) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
        debugPrint("☁️ AuthRepository: Sync event received, refreshing (debounced)...");
        _loadUsers();
      });
    });
  }


  Future<void> _loadUsers() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool(_migrationKey) ?? false;

    if (!isMigrated) {
      _isLoading = true;
      notifyListeners();
      try {
        await _migrateFromSharedPrefs(prefs);
      } catch (e) {
        debugPrint("❌ CRITICAL: Migration failed: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }

    try {
      _users = await DatabaseHelper.instance.getPatients();
      
      // NEW: Trigger sync if we have a persisted session
      final encryptedLastUserId = prefs.getString('last_logged_in_user_id');
      if (encryptedLastUserId != null && _currentUser == null) {
        try {
          final lastUserId = EncryptionService().decryptData(encryptedLastUserId);
          _currentUser = _users.firstWhere((u) => u.id == lastUserId);
          if (_currentUser != null) {
            SyncService().restartSync(_currentUser!.id);
            SyncService().fullSyncForUser(_currentUser!.id);
          }
        } catch (_) {
          debugPrint("⚠️ AuthRepository: Stale or unreadable session found. Clearing.");
          await prefs.remove('last_logged_in_user_id');
        }
      }
    } catch (e) {
      debugPrint("❌ CRITICAL: Failed to load users from SQLite: $e");
      _users = [];
    } finally {
      _isRefreshing = false;
    }
    notifyListeners();
  }

  Future<void> _migrateFromSharedPrefs(SharedPreferences prefs) async {
    debugPrint("🚀 Starting Migration to SQLite...");

    try {
      // 1. Try to load legacy encrypted users
      final encrypted = prefs.getString(_storageKey);
      List<User> legacyUsers = [];

      if (encrypted != null) {
        try {
          final decrypted = EncryptionService().decryptData(encrypted);
          final List<dynamic> jsonList = jsonDecode(decrypted);
          legacyUsers = jsonList.map((json) => User.fromMap(json)).toList();
        } catch (e) {
          debugPrint("⚠️ Migration Trace (Encrypted Load Failed): $e");
        }
      }

      // 2. Try plain text legacy
      final legacyPlain = prefs.getStringList('kiosk_users');
      if (legacyPlain != null) {
        legacyUsers.addAll(legacyPlain.map((item) => User.fromJson(item)));
      }

      // 3. Insert into SQLite
      for (final user in legacyUsers) {
        try {
          await DatabaseHelper.instance.insertPatient(user);
        } catch (e) {
          debugPrint("⚠️ Migration Trace (Single User Insert Failed): $e");
        }
      }

      await prefs.setBool(_migrationKey, true);
      debugPrint("✅ Migration to SQLite Complete.");
    } catch (e) {
      debugPrint("❌ CRITICAL: Migration process exploded: $e");
      rethrow;
    }
  }

  // Called explicitly by SyncService after downloading from cloud
  @override
  Future<void> refreshUsers() async {
    await _loadUsers();
  }

  @override
  Future<String?> registerUser(User newUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      final syncService = SyncService();

      final createdUser = await syncService.createPatient(newUser);

      if (createdUser == null) {
        _isLoading = false;
        notifyListeners();
        return "Failed to register patient locally.";
      }

      // 3. Save to SQLite
      await DatabaseHelper.instance.insertPatient(createdUser);
      _users = await DatabaseHelper.instance.getPatients();
      _currentUser = createdUser;

      SecurityLogger.info("New patient registered", 
          pii: createdUser.fullName);
      
      DatabaseHelper.instance.logSecurityEvent(
          "REGISTER", "New patient registered", // Event log sanitized internally or masked
          userId: createdUser.id);

      // Trigger immediate background sync push
      SyncService().triggerSync();

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Registration Error: $e";
    }
  }

  // --- NEW: UPDATE USER ---
  @override
  Future<void> updateUser(User updatedUser) async {
    await DatabaseHelper.instance.updatePatient(updatedUser);
    _users = await DatabaseHelper.instance.getPatients();

    SecurityLogger.info("Admin updated user", pii: updatedUser.fullName);

    DatabaseHelper.instance.logSecurityEvent(
        "USER_UPDATE", "Admin updated user details",
        userId: "ADMIN");

    // Trigger Cloud Sync
    SyncService().updatePatient(updatedUser);
    notifyListeners();
  }

  @override
  Future<void> deleteUser(String userId) async {
    await DatabaseHelper.instance.deletePatient(userId);
    _users = await DatabaseHelper.instance.getPatients();

    DatabaseHelper.instance.logSecurityEvent(
        "USER_DELETE", "Admin deleted user ID: $userId",
        userId: "ADMIN");

    // Trigger Cloud Sync
    SyncService().deletePatient(userId);
    notifyListeners();
  }

  @override
  Future<void> toggleUserStatus(User user, bool isActive) async {
    final updatedUser = user.copyWith(isActive: isActive);
    await DatabaseHelper.instance.updatePatient(updatedUser);

    _users = await DatabaseHelper.instance.getPatients();

    SecurityLogger.info("Admin ${isActive ? 'restored' : 'archived'} user", pii: user.fullName);

    DatabaseHelper.instance.logSecurityEvent("USER_ARCHIVE",
        "Admin ${isActive ? 'restored' : 'archived'} user",
        userId: "ADMIN");

    // Trigger Cloud Sync
    SyncService().updatePatient(updatedUser);
    notifyListeners();
  }

  // Login Logic (Lookup by Name + Phone)
  @override
  Future<String?> login(String firstName, String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Local Offline Check (SQLite)
      // Since local SQLite data is stored with deterministic re-encryption (or plain if using getPatients),
      // the comparison here might be tricky if the Repository list is stale.
      // But _loadUsers correctly decrypts when loading.
      final localUser = _users.where((u) => 
        (u.firstName.toLowerCase().contains(firstName.toLowerCase()) || 
         u.fullName.toLowerCase().contains(firstName.toLowerCase())) &&
        u.phoneNumber.trim() == phoneNumber.trim()
      ).toList();

      if (localUser.isNotEmpty) {
        _currentUser = localUser.first;
        return _handleSuccessfulLogin();
      }

      // 2. Cloud Fallback (Critical for new accounts not yet pulled)
      final cloudMatches = await SyncService().findPatient(firstName, phoneNumber);
      if (cloudMatches.isNotEmpty) {
        final cloudUser = User.fromMap(cloudMatches.first);
        await DatabaseHelper.instance.insertPatient(cloudUser);
        _users = await DatabaseHelper.instance.getPatients();
        _currentUser = _users.firstWhere((u) => u.id == cloudUser.id);
        return _handleSuccessfulLogin();
      }

      _isLoading = false;
      notifyListeners();
      return "Patient not found or Credentials mismatch. Please ensure you are registered.";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Login Error: $e";
    }
  }

  /// Extracted shared login success logic
  Future<String?> _handleSuccessfulLogin() async {
    if (_currentUser == null) return "Unknown Error";

    final prefs = await SharedPreferences.getInstance();
    
    // Fetch Dependents
    final dependents = await SyncService().fetchDependents(_currentUser!.id);
    for (final dependent in dependents) {
      await DatabaseHelper.instance.insertPatient(dependent);
    }
    _users = await DatabaseHelper.instance.getPatients();

    // Save session
    final encryptedId = EncryptionService().encryptData(_currentUser!.id);
    await prefs.setString('last_logged_in_user_id', encryptedId);

    // EAGER SYNC & SESSION RESTART
    SyncService().restartSync(_currentUser!.id);
    SyncService().fullSyncForUser(_currentUser!.id);
    
    // Update cloud push token (Stub for native device token)
    if (_currentUser!.deviceToken != null) {
      await NotificationService().updateDeviceToken(_currentUser!.id, _currentUser!.deviceToken!);
    }

    // Listeners
    ChatListenerService().startListening(_currentUser!.id);
    AnnouncementListenerService().startListening();
    SystemLogService().startSession(_currentUser!.id);
    SystemAlertListenerService().startListening(
      userRole: 'patient',
      sitio: _currentUser!.sitio,
    );
    VitalsListenerService().startListening(
      familyIds: getLinkedAccounts().map((u) => u.id).toList(),
    );

    _isLoading = false;
    notifyListeners();
    return null;
  }


  // --- KIOSK QR LOGIN ---
  @override
  Future<String?> loginWithId(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final localUser = _users.firstWhere(
        (u) => u.id == userId,
        orElse: () => User(
            id: '',
            firstName: '',
            middleInitial: '',
            lastName: '',
            sitio: '',
            phoneNumber: '',
            pinCode: '',
            dateOfBirth: DateTime.now(),
            gender: ''),
      );

      if (localUser.id.isNotEmpty) {
        _currentUser = localUser;
        _isLoading = false;
        // Start background listeners
        ChatListenerService().startListening(_currentUser!.id);
        SystemLogService().startSession(_currentUser!.id);
        SystemAlertListenerService().startListening(
          userRole: 'patient',
          sitio: _currentUser!.sitio,
        );
        SyncService()
            .syncFamilyVitals(getLinkedAccounts().map((u) => u.id).toList());

        notifyListeners();
        return null; // Success
      }

      _isLoading = false;
      notifyListeners();
      return "Patient not found. Ensure the Kiosk is synced.";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Login Error: $e";
    }
  }

  // --- MOBILE COMPANION APP LOGIN ---
  @override
  Future<String?> loginPatientDevice(String phone, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      final cloudUser = await SyncService().authenticatePatient(phone, pin);
      if (cloudUser != null) {
        // Fetch Dependents for the logged-in parent
        final dependents = await SyncService().fetchDependents(cloudUser.id);

        _users = [cloudUser, ...dependents];

        // Save to SQLite for persistence
        await DatabaseHelper.instance.insertPatient(cloudUser);
        for (final dependent in dependents) {
          await DatabaseHelper.instance.insertPatient(dependent);
        }

        _currentUser = cloudUser;
        _isLoading = false;
        // Start background listeners
        ChatListenerService().startListening(_currentUser!.id);
        SystemLogService().startSession(_currentUser!.id);
        SystemAlertListenerService().startListening(
          userRole: 'patient',
          sitio: _currentUser!.sitio,
        );

        notifyListeners();

        // Sync all family vitals for offline access
        SyncService()
            .syncFamilyVitals(getLinkedAccounts().map((u) => u.id).toList());

        return null; // Navigation will trigger
      } else {
        _isLoading = false;
        notifyListeners();
        return "Invalid Phone Number or PIN. Please try again or contact your BHW.";
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Network Error: Could not reach the server.";
    }
  }

  // Legacy locking logic removed as there is no password to fail.

  @override
  Future<void> logout() async {
    final mode = AppEnvironment().mode;

    if (_currentUser != null) {
      // PREVENT CRASH: Await security logging before resetting state
      try {
        await DatabaseHelper.instance.logSecurityEvent(
            "LOGOUT", "User logged out",
            userId: _currentUser!.id);
      } catch (e) {
        debugPrint("⚠️ Logout log failed (non-fatal): $e");
      }

      // 1. CLEAR CLOUD PUSH TOKEN - Security Requirement
      await NotificationService().clearDeviceToken(_currentUser!.id);

      // Stop background listeners
      ChatListenerService().stopListening();
      SystemAlertListenerService().stopListening();

      // Only stop sync listeners on mobile; Kiosk/Desktop should keep listening
      if (mode == AppMode.mobilePatient) {
        SyncService().reset(); // Use new reset() for full teardown
      }

      // Log session end
      await SystemLogService().endSession();
    }

    _currentUser = null;

    if (mode == AppMode.mobilePatient) {
      _users.clear();
      notifyListeners();
    } else {
      // For Kiosk/Desktop Admin, immediately reload users to keep the device ready
      await _loadUsers();
    }
  }

  // --- DEPENDENT MANAGEMENT ---
  @override
  void switchUser(User user) {
    if (_users.any((u) => u.id == user.id)) {
      _currentUser = user;
      notifyListeners();
    }
  }

  @override
  List<User> getLinkedAccounts() {
    if (_currentUser == null) return [];
    final parentId = _currentUser!.parentId ?? _currentUser!.id;
    return _users
        .where((u) => u.id == parentId || u.parentId == parentId)
        .toList();
  }

  // --- SYNC SUPPORT MODULES ---
  List<User> getUnsyncedUsers() {
    return _users.where((user) => !user.isSynced).toList();
  }

  Future<void> markUserAsSynced(String userId) async {
    await DatabaseHelper.instance.markPatientAsSynced(userId);
    _users = await DatabaseHelper.instance.getPatients();
    notifyListeners();
  }

  // --- INTERFACE STUBS & HELPERS ---
  @override
  Future<bool> verifyAdminAccess(String pin) async => false;

  @override
  Future<bool> setPinCode(String newPin) async => false;

  @override
  Future<bool> verifyPatientPin(String enteredPin) async => false;

  @override
  User? getUserById(String uid) {
    try {
      return _users.firstWhere((u) => u.id == uid);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<User>> searchPatients(String query) async {
    return await SyncService().searchPatients(query);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _patientSyncSub?.cancel();
    super.dispose();
  }
}
