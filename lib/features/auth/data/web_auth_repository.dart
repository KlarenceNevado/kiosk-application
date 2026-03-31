import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/models/user_model.dart';
import '../domain/i_auth_repository.dart';
import '../../../core/services/security/encryption_service.dart';
import '../../../core/services/security/notification_service.dart';
import '../../../core/services/database/sync_service.dart';


/// Web-safe AuthRepository that uses Supabase directly.
/// Persists session to SharedPreferences so browser reloads don't lose the user.
class WebAuthRepository extends ChangeNotifier implements IAuthRepository {
  User? _currentUser;
  List<User> _users = [];
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;
  static const _sessionKey = 'pwa_session_user_id';
  final _restoreCompleter = Completer<void>();

  @override
  User? get currentUser => _currentUser;
  @override
  List<User> get users => _users;
  @override
  bool get isLoading => _isLoading;

  @override
  Future<void> get initialization => _restoreCompleter.future;

  WebAuthRepository() {
    // Restore session from SharedPreferences on construction
    _restoreSession();
  }

  /// Restores the user session from SharedPreferences after a browser reload.
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString(_sessionKey);
      if (storedUserId == null || storedUserId.isEmpty) return;

      debugPrint("🔐 Restoring PWA session for user: $storedUserId");

      // Re-fetch user from Supabase
      final response = await _supabase
          .from('patients')
          .select()
          .eq('id', storedUserId)
          .maybeSingle();

      if (response == null) {
        debugPrint("⚠️ Session restore: User not found in database. Clearing session.");
        await prefs.remove(_sessionKey);
        return;
      }

      final restoredUser = User.fromMap(response);

      // Fetch dependents
      final depsResponse = await _supabase
          .from('patients')
          .select()
          .eq('parent_id', restoredUser.id);

      final dependents = (depsResponse as List)
          .map((row) => User.fromMap(row))
          .toList();

      _users = [restoredUser, ...dependents];
      _currentUser = restoredUser;
      debugPrint("✅ Session restored: ${restoredUser.fullName}");

      // RE-INITIALIZE DATA FLOW
      SyncService().restartSync(restoredUser.id);

      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ Session restore failed: $e");
    } finally {
      if (!_restoreCompleter.isCompleted) {
        _restoreCompleter.complete();
      }
    }
  }

  /// Saves the current user ID to SharedPreferences.
  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  /// Clears the stored session.
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<List<User>> searchPatients(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // Corrected: Uses .or() for first/last name search on Supabase
      // Removed role and is_deleted as they are not in the consolidated schema
      final response = await _supabase
          .from('patients')
          .select()
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%')
          .limit(10);
      
      return (response as List).map((json) => User.fromMap(json)).toList();
    } catch (_) {
      return [];
    }
  }


  /// Mobile Companion Login (Phone + PIN) — Cloud only
  @override
  Future<String?> loginPatientDevice(String phone, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      // NOTE: Because Phone/PIN are encrypted with random IVs, 
      // we can't query them directly with .eq(). 
      // This is a trade-off for security.
      // On the Web PWA, we usually expect the user to have found themselves by name first.
      // If they are logging in via Phone+PIN, we have to fetch and decrypt.
      // Since this is inefficient, we limit search and encourage using Name search first.
      final response = await _supabase
          .from('patients')
          .select()
          .limit(100); // Fetch a small batch to scan locally

      final List<dynamic> data = response as List;
      User? match;

      for (var row in data) {
        final dbEncPhone = row['phone_number'] as String?;
        final dbEncPin = row['pin_code'] as String?;
        if (dbEncPhone == null || dbEncPin == null) continue;

        final decPhone = EncryptionService().decryptData(dbEncPhone);
        final decPin = EncryptionService().decryptData(dbEncPin);

        if (decPhone == phone.trim() && decPin == pin.trim()) {
          match = User.fromMap(row);
          break;
        }
      }

      if (match != null) {
        final cloudUser = match;

        // Fetch dependents
        final depsResponse = await _supabase
            .from('patients')
            .select()
            .eq('parent_id', cloudUser.id);

        final dependents = (depsResponse as List)
            .map((row) => User.fromMap(row))
            .toList();

        _users = [cloudUser, ...dependents];
        _currentUser = cloudUser;
        await _saveSession(cloudUser.id);

        // RE-INITIALIZE SYSTEM LIFECYCLE
        SyncService().restartSync();
        // Assuming push token is available from a native service (stub for now)
        if (cloudUser.deviceToken != null) {
          await NotificationService().updateDeviceToken(cloudUser.id, cloudUser.deviceToken!);
        }

        _isLoading = false;
        notifyListeners();
        return null; // Success
      } else {
        _isLoading = false;
        notifyListeners();
        return "Account not found with provided credentials.";
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Network Error: Could not reach the server.";
    }
  }



  /// Login by Name + Phone (for Kiosk-style login on web)
  @override
  Future<String?> login(String firstName, String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Search by name (Names are PLAIN TEXT in Supabase)
      // We search by first_name as a starting point
      final response = await _supabase
          .from('patients')
          .select()
          .ilike('first_name', '%$firstName%')
          .limit(20);

      final List<dynamic> data = response as List;
      
      // 2. Local Decryption Check
      // We cannot use .eq() on phone_number because of random IVs.
      // We must fetch by name and check the decrypted phone number locally.
      User? match;
      for (var row in data) {
        final dbEncPhone = row['phone_number'] as String?;
        if (dbEncPhone == null) continue;

        final decryptedPhone = EncryptionService().decryptData(dbEncPhone);
        if (decryptedPhone == phoneNumber.trim()) {
          match = User.fromMap(row);
          break;
        }
      }

      if (match != null) {
        final cloudUser = match;

        // Fetch dependents
        final depsResponse = await _supabase
            .from('patients')
            .select()
            .eq('parent_id', cloudUser.id);

        final dependents = (depsResponse as List)
            .map((row) => User.fromMap(row))
            .toList();

        _users = [cloudUser, ...dependents];
        _currentUser = cloudUser;
        await _saveSession(cloudUser.id);

        // RE-INITIALIZE SYSTEM LIFECYCLE
        SyncService().restartSync(cloudUser.id);

        _isLoading = false;
        notifyListeners();
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return "Patient and Phone combination not found. Please verify your details.";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Login Error: $e";
    }
  }



  @override
  Future<void> logout() async {
    final oldUser = _currentUser;
    _currentUser = null;
    _users.clear();
    await _clearSession();

    // 1. CLEAR CLOUD PUSH TOKEN - Security Requirement
    if (oldUser != null) {
      await NotificationService().clearDeviceToken(oldUser.id);
    }
    
    // 2. STOP ALL REAL-TIME DATA FLOW - Stability Requirement
    SyncService().reset();

    // 3. ACTUAL SUPABASE SIGNOUT
    await _supabase.auth.signOut();

    notifyListeners();
  }

  @override
  void switchUser(User user) {
    if (_users.any((u) => u.id == user.id)) {
      _currentUser = user;
      notifyListeners();
    }
  }

  @override
  List<User> getLinkedAccounts() {
    if (_currentUser == null) {
      return [];
    }
    final parentId = _currentUser!.parentId ?? _currentUser!.id;
    return _users
        .where((u) => u.id == parentId || u.parentId == parentId)
        .toList();
  }

  @override
  void resetSessionTimer() {
    // Current PWA implementation is session-based via Supabase/LocalStorage
    // and does not yet enforce an inactivity timeout. This is a no-op for now.
  }

  // Stubs for methods that may be called from shared UI but are no-ops on web
  @override
  Future<void> refreshUsers() async {}
  @override
  Future<String?> registerUser(User newUser) async => "Registration is only available at the Kiosk.";
  @override
  Future<void> updateUser(User updatedUser) async {}
  @override
  Future<void> deleteUser(String userId) async {}
  @override
  Future<void> toggleUserStatus(User user, bool isActive) async {}
  @override
  Future<String?> loginWithId(String userId) async => "QR Login is only available at the Kiosk.";
  List<User> getUnsyncedUsers() => [];
  Future<void> markUserAsSynced(String userId) async {}

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
}
