import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Abstract interface for authentication and user management.
/// This allows us to inject either the Native (SQLite) or Web (Supabase) repository at runtime,
/// achieving 100% UI feature parity without breaking web compilation.
abstract class IAuthRepository extends ChangeNotifier {
  User? get currentUser;
  List<User> get users;
  bool get isLoading;
  Future<void> get initialization;

  Future<void> refreshUsers();

  // Registration & User Management
  Future<List<User>> searchPatients(String query);
  Future<String?> registerUser(User newUser);
  Future<void> updateUser(User updatedUser);
  Future<void> deleteUser(String userId);
  Future<void> toggleUserStatus(User user, bool isActive);

  // Login Flows
  Future<String?> login(String username, String phoneNumber);
  Future<String?> loginWithId(String userId);
  Future<String?> loginPatientDevice(String phone, String pin);
  Future<void> loginAsVisitor(String fullName);
  Future<String?> loginWithFingerprint(int fingerprintId);
  Future<void> logout();
  void resetSessionTimer();

  // PIN specific logic (mainly for Patient apps)
  Future<bool> verifyAdminAccess(String pin) async =>
      false; // Default implementations to avoid massive refactoring overhead
  Future<bool> setPinCode(String newPin) async => false;
  Future<bool> verifyPatientPin(String enteredPin) async => false;

  // Family/Dependent Links
  List<User> getLinkedAccounts();
  void switchUser(User account);
  User? getUserById(String uid) {
    try {
      return users.firstWhere((u) => u.id == uid);
    } catch (_) {
      return null;
    }
  }
}
