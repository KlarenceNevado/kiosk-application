import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../auth/models/user_model.dart';

/// Web-safe AuthRepository that uses Supabase directly.
/// No DatabaseHelper, SyncService, EncryptionService, or dart:io.
class AuthRepository extends ChangeNotifier {
  User? _currentUser;
  List<User> _users = [];
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  User? get currentUser => _currentUser;
  List<User> get users => _users;
  bool get isLoading => _isLoading;

  AuthRepository() {
    // No auto-load on web; user must log in explicitly.
  }

  /// Mobile Companion Login (Phone + PIN) — Cloud only
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

  Future<void> logout() async {
    _currentUser = null;
    _users.clear();
    notifyListeners();
  }

  void switchUser(User user) {
    if (_users.any((u) => u.id == user.id)) {
      _currentUser = user;
      notifyListeners();
    }
  }

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
  Future<void> refreshUsers() async {}
  Future<String?> registerUser(User newUser) async => "Registration is only available at the Kiosk.";
  Future<void> updateUser(User updatedUser) async {}
  Future<void> deleteUser(String userId) async {}
  Future<void> toggleUserStatus(User user, bool isActive) async {}
  Future<String?> loginWithId(String userId) async => "QR Login is only available at the Kiosk.";
  List<User> getUnsyncedUsers() => [];
  Future<void> markUserAsSynced(String userId) async {}
}
