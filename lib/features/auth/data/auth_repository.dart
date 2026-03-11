import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/database/database_helper.dart';
import '../../../core/services/database/sync_service.dart'; // NEW
import '../../../core/services/security/encryption_service.dart';
import '../../../core/services/system/app_environment.dart';
import '../models/user_model.dart';
import '../../../core/services/notifications/chat_listener_service.dart';
import '../../../core/services/notifications/system_alert_listener_service.dart';
import '../../../core/services/notifications/announcement_listener_service.dart';

class AuthRepository extends ChangeNotifier {
  User? _currentUser;
  List<User> _users = [];
  bool _isLoading = false;
  StreamSubscription? _patientSyncSub;

  // STORAGE KEYS
  static const String _migrationKey = 'sqlite_migration_done';
  static const String _storageKey = 'secure_kiosk_users';

  User? get currentUser => _currentUser;
  List<User> get users => _users;
  bool get isLoading => _isLoading;

  AuthRepository() {
    _loadUsers();
    SyncService().registerSyncCallback(_syncOfflineUsers);

    // Listen for cloud changes and refresh local list
    _patientSyncSub = SyncService().patientStream.listen((_) {
      debugPrint("☁️ AuthRepository: Patient change detected, refreshing...");
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _patientSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _syncOfflineUsers() async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedPatients();
    for (final user in unsynced) {
      final updatedUser = await SyncService().createPatient(user);
      if (updatedUser != null && updatedUser.isSynced) {
        await DatabaseHelper.instance.markPatientAsSynced(updatedUser.id);
      }
    }
  }

  Future<void> _loadUsers() async {
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
    } catch (e) {
      debugPrint("❌ CRITICAL: Failed to load users from SQLite: $e");
      _users = [];
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
  Future<void> refreshUsers() async {
    await _loadUsers();
  }

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

      DatabaseHelper.instance.logSecurityEvent(
          "REGISTER", "New patient registered: ${createdUser.fullName}",
          userId: createdUser.id);

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
  Future<void> updateUser(User updatedUser) async {
    await DatabaseHelper.instance.updatePatient(updatedUser);
    _users = await DatabaseHelper.instance.getPatients();

    DatabaseHelper.instance.logSecurityEvent(
        "USER_UPDATE", "Admin updated user: ${updatedUser.fullName}",
        userId: "ADMIN");

    // Trigger Cloud Sync
    SyncService().updatePatient(updatedUser);
    notifyListeners();
  }

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

  Future<void> toggleUserStatus(User user, bool isActive) async {
    final updatedUser = user.copyWith(isActive: isActive);
    await DatabaseHelper.instance.updatePatient(updatedUser);

    _users = await DatabaseHelper.instance.getPatients();

    DatabaseHelper.instance.logSecurityEvent("USER_ARCHIVE",
        "Admin ${isActive ? 'restored' : 'archived'} user: ${user.fullName}",
        userId: "ADMIN");

    // Trigger Cloud Sync
    SyncService().updatePatient(updatedUser);
    notifyListeners();
  }

  // Login Logic (Lookup by Name + Phone)
  Future<String?> login(String firstName, String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Offline Check (Online Mode removed for backend migration)
      final localUser = _users.firstWhere(
        (u) =>
            (u.firstName.toLowerCase() == firstName.toLowerCase() ||
                u.fullName.toLowerCase() == firstName.toLowerCase()) &&
            u.phoneNumber == phoneNumber,
        orElse: () => User(
            id: '',
            firstName: '',
            middleInitial: '',
            lastName: '',
            sitio: '',
            phoneNumber: '',
            pinCode: '123456',
            dateOfBirth: DateTime.now(),
            gender: ''),
      );

      if (localUser.id.isNotEmpty) {
        _currentUser = localUser;
        _isLoading = false;
        // Start background listeners
        ChatListenerService().startListening(_currentUser!.id);
        AnnouncementListenerService().startListening();
        SystemAlertListenerService().startListening(
          userRole: 'patient',
          sitio: _currentUser!.sitio,
        );

        notifyListeners();
        return null;
      }

      // 2. Cloud Check (Fallback for Mobile App matching Name + Phone)
      final cloudCheck =
          await SyncService().findPatient(firstName, phoneNumber);
      if (cloudCheck.isNotEmpty) {
        _currentUser = User.fromMap(cloudCheck.first);
        _isLoading = false;
        // Start background listeners
        ChatListenerService().startListening(_currentUser!.id);
        AnnouncementListenerService().startListening();
        SystemAlertListenerService().startListening(
          userRole: 'patient',
          sitio: _currentUser!.sitio,
        );

        notifyListeners();
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return "Patient not found. Please register.";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Login Error: $e";
    }
  }

  // --- KIOSK QR LOGIN ---
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
        AnnouncementListenerService().startListening();
        SystemAlertListenerService().startListening(
          userRole: 'patient',
          sitio: _currentUser!.sitio,
        );

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
        AnnouncementListenerService().startListening();
        SystemAlertListenerService().startListening(
          userRole: 'patient',
          sitio: _currentUser!.sitio,
        );

        notifyListeners();
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

      // Stop background listeners
      ChatListenerService().stopListening();
      AnnouncementListenerService().stopListening();
      SystemAlertListenerService().stopListening();

      // Only stop sync listeners on mobile; Kiosk/Desktop should keep listening
      if (mode == AppMode.mobilePatient) {
        SyncService().stopListening();
      }
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
  void switchUser(User user) {
    if (_users.any((u) => u.id == user.id)) {
      _currentUser = user;
      notifyListeners();
    }
  }

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
}
