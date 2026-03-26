import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../auth/models/user_model.dart';
import '../domain/i_auth_repository.dart';

/// Web-safe AuthRepository that uses Supabase directly.
/// No DatabaseHelper, SyncService, EncryptionService, or dart:io.
class WebAuthRepository extends ChangeNotifier implements IAuthRepository {
  User? _currentUser;
  List<User> _users = [];
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  @override
  User? get currentUser => _currentUser;
  @override
  List<User> get users => _users;
  @override
  bool get isLoading => _isLoading;

  WebAuthRepository() {
    // No auto-load on web; user must log in explicitly.
  }

  @override
  Future<List<User>> searchPatients(String query) async {
    try {
      final response = await _supabase
          .from('patients')
          .select()
          .ilike('full_name', '%$query%')
          .eq('role', 'patient')
          .eq('is_deleted', false)
          .limit(10);
      
      return (response as List).map((json) => User.fromJson(json)).toList();
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
      // Query Supabase directly
      final response = await _supabase
          .from('patients')
          .select()
          .eq('phone_number', phone)
          .eq('pin_code', pin)
          .eq('is_deleted', false)
          .maybeSingle();

      if (response != null) {
        final cloudUser = User.fromMap(response);

        // Fetch dependents
        final depsResponse = await _supabase
            .from('patients')
            .select()
            .eq('parent_id', cloudUser.id)
            .eq('is_deleted', false);

        final dependents = (depsResponse as List)
            .map((row) => User.fromMap(row))
            .toList();

        _users = [cloudUser, ...dependents];
        _currentUser = cloudUser;
        _isLoading = false;
        notifyListeners();
        return null; // Success
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

  /// Login by Name + Phone (for Kiosk-style login on web)
  @override
  Future<String?> login(String firstName, String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('patients')
          .select()
          .eq('phone_number', phoneNumber)
          .eq('is_deleted', false);

      final List<dynamic> data = response as List;
      final match = data.where((row) {
        final fn = (row['first_name'] ?? '').toString().toLowerCase();
        final ln = (row['last_name'] ?? '').toString().toLowerCase();
        final full = '$fn $ln';
        final query = firstName.toLowerCase();
        return fn == query || full == query;
      }).toList();

      if (match.isNotEmpty) {
        final cloudUser = User.fromMap(match.first);

        // Fetch dependents
        final depsResponse = await _supabase
            .from('patients')
            .select()
            .eq('parent_id', cloudUser.id)
            .eq('is_deleted', false);

        final dependents = (depsResponse as List)
            .map((row) => User.fromMap(row))
            .toList();

        _users = [cloudUser, ...dependents];
        _currentUser = cloudUser;
        _isLoading = false;
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

  @override
  Future<void> logout() async {
    _currentUser = null;
    _users.clear();
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
