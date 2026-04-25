import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../../../features/auth/models/user_model.dart';

enum AdminRole { superAdmin, staffAdmin, none }

class AdminSecurityService {
  static final AdminSecurityService _instance =
      AdminSecurityService._internal();
  factory AdminSecurityService() => _instance;
  AdminSecurityService._internal();

  static const String _keyAdminPin = 'secure_admin_pin_hash';
  static const String _keyAdminSalt = 'secure_admin_pin_salt';
  static const String _keyStaffAdminPin = 'secure_staff_pin_hash';
  static const String _keyStaffAdminSalt = 'secure_staff_pin_salt';
  static const String _keyLockoutUntil = 'secure_admin_lockout_until';

  AdminRole currentRole = AdminRole.none;
  User? activeStaff;

  /// Gets a unique hardware fingerprint for this machine to bind the PIN
  String _getHardwareFingerprint() {
    // Combine hostname and OS version as a stable machine identity
    return "${Platform.localHostname}-${Platform.operatingSystemVersion}";
  }

  /// Generates a unique salt for this device if it doesn't exist
  Future<String> _getOrGenerateSalt() async {
    final prefs = await SharedPreferences.getInstance();
    String? salt = prefs.getString(_keyAdminSalt);
    if (salt == null) {
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      // Bind salt to hardware fingerprint
      final fingerprint = _getHardwareFingerprint();
      salt =
          "${base64.encode(values)}:${base64.encode(utf8.encode(fingerprint))}";
      await prefs.setString(_keyAdminSalt, salt);
    }
    return salt;
  }

  /// Sets a persistent lockout timestamp
  Future<void> setLockout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(Duration(seconds: seconds));
    await prefs.setString(_keyLockoutUntil, until.toIso8601String());
  }

  /// Gets the remaining lockout duration in seconds, or 0 if not locked
  Future<int> getRemainingLockoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lockoutStr = prefs.getString(_keyLockoutUntil);
    if (lockoutStr == null) return 0;

    final until = DateTime.parse(lockoutStr);
    final diff = until.difference(DateTime.now()).inSeconds;

    if (diff <= 0) {
      await prefs.remove(_keyLockoutUntil);
      return 0;
    }
    return diff;
  }

  /// Helper to hash the PIN string with a salt
  String _hashPin(String pin, String salt) {
    final saltedBytes = utf8.encode(pin + salt);
    final digest = sha256.convert(saltedBytes);
    return digest.toString();
  }

  /// Checks if the provided PIN matches the stored secure PIN or any registered staff PIN
  /// Returns the role associated with the PIN, or AdminRole.none if invalid
  Future<AdminRole> verifyPin(String inputPin, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedSuperHash = prefs.getString(_keyAdminPin);
    final String? storedStaffHash = prefs.getString(_keyStaffAdminPin);

    // 1. MASTER SUPER ADMIN CHECK (Highest Priority)
    if (storedSuperHash != null) {
      final superSalt = await _getOrGenerateSalt();
      final inputSuperHash = _hashPin(inputPin, superSalt);
      if (_compareHashes(inputSuperHash, storedSuperHash)) {
        currentRole = AdminRole.superAdmin;
        activeStaff = User.empty().copyWith(firstName: "Super", lastName: "Admin", role: "admin");
        return AdminRole.superAdmin;
      }
    }

    // 2. SPECIFIC USER CHECK (If userId provided)
    if (userId != null) {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query('residents', where: 'id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        final user = User.fromMap(maps.first);
        if (user.role == 'admin' || user.role == 'bhw') {
          // Verify PIN (Legacy or Hash)
          bool isValid = false;
          if (user.pinHash != null && user.pinSalt != null) {
            final hashedInput = _hashPin(inputPin, user.pinSalt!);
            isValid = _compareHashes(hashedInput, user.pinHash!);
          } else {
            isValid = user.pinCode == inputPin;
          }

          if (isValid) {
            activeStaff = user;
            currentRole = user.role == 'admin' ? AdminRole.superAdmin : AdminRole.staffAdmin;
            return currentRole;
          }
        }
      }
    }

    // 3. LEGACY/GLOBAL STAFF PIN CHECK (Fallback)
    if (storedStaffHash != null) {
      final staffSalt = prefs.getString(_keyStaffAdminSalt) ?? await _getOrGenerateSalt();
      final inputStaffHash = _hashPin(inputPin, staffSalt);
      if (_compareHashes(inputStaffHash, storedStaffHash)) {
        currentRole = AdminRole.staffAdmin;
        activeStaff = User.empty().copyWith(firstName: "General", lastName: "BHW", role: "bhw");
        return AdminRole.staffAdmin;
      }
    }

    // 4. ANY MATCHING STAFF PIN (If no userId provided, search for first match)
    if (userId == null) {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query('residents', 
        where: 'role IN ("admin", "bhw") AND pinCode = ?', 
        whereArgs: [inputPin]);
      
      if (maps.isNotEmpty) {
        final user = User.fromMap(maps.first);
        activeStaff = user;
        currentRole = user.role == 'admin' ? AdminRole.superAdmin : AdminRole.staffAdmin;
        return currentRole;
      }
    }

    return AdminRole.none;
  }

  bool _compareHashes(String inputHash, String storedHash) {
    if (inputHash.length != storedHash.length) return false;
    int result = 0;
    for (int i = 0; i < inputHash.length; i++) {
      result |= inputHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Updates the Admin PIN securely
  Future<bool> setAdminPin(String newPin) async {
    if (newPin.length < 4 || newPin.length > 8) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isFirstSetup = !prefs.containsKey(_keyAdminPin);

      // 1. Get/Generate Salt
      final salt = await _getOrGenerateSalt();

      // 2. Hash the PIN with salt
      final hashedPin = _hashPin(newPin, salt);

      // 3. Save only the cryptographic hash to disk
      await prefs.setString(_keyAdminPin, hashedPin);

      await DatabaseHelper.instance.logSecurityEvent(
          isFirstSetup ? "PIN_SETUP" : "PIN_UPDATE",
          isFirstSetup
              ? "Initial Admin PIN established with encrypted salt."
              : "Admin PIN updated with fresh cryptographic signature.",
          severity: "HIGH");

      if (isFirstSetup) {
        currentRole =
            AdminRole.superAdmin; // Assume super admin if just setting up
      }

      return true;
    } catch (e) {
      debugPrint("Security Error: Failed to save PIN. $e");
      return false;
    }
  }

  /// Updates the Staff Admin PIN securely
  Future<bool> setStaffPin(String newPin) async {
    if (newPin.length < 4 || newPin.length > 8) return false;

    try {
      final prefs = await SharedPreferences.getInstance();

      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      final staffSalt = base64.encode(values);
      await prefs.setString(_keyStaffAdminSalt, staffSalt);

      final hashedPin = _hashPin(newPin, staffSalt);
      await prefs.setString(_keyStaffAdminPin, hashedPin);

      await DatabaseHelper.instance.logSecurityEvent(
          "STAFF_PIN_UPDATE", "Staff Admin PIN was updated.",
          severity: "MEDIUM");

      return true;
    } catch (e) {
      debugPrint("Security Error: Failed to save Staff PIN. $e");
      return false;
    }
  }

  /// Checks if the system is missing an Admin PIN or if it's in an inconsistent state (Legacy)
  Future<bool> isPinSetupRequired() async {
    final prefs = await SharedPreferences.getInstance();

    // If no PIN exists, obviously setup is required
    if (!prefs.containsKey(_keyAdminPin)) return true;

    // If a PIN exists but NO SALT exists, it's a legacy PIN that will never pass verification
    // because the new hashing expects a salt. We must treat this as "Setup Required".
    if (!prefs.containsKey(_keyAdminSalt)) {
      debugPrint(
          "Security Integrity Warning: Legacy PIN detected without salt. Resetting state.");
      await prefs.remove(_keyAdminPin);
      return true;
    }

    return false;
  }

  /// ELITE SECURITY: Dev-Mode Reset
  /// Allows clearing the PIN if a physical 'reset.key' exists in the data directory.
  /// This is the only way to recover a lost PIN without wiping the entire database.
  Future<bool> checkForDeveloperReset() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final resetFile = File('${directory.path}/kiosk_security_reset.key');

      if (await resetFile.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyAdminPin);
        await prefs.remove(_keyAdminSalt);
        await prefs.remove(_keyStaffAdminPin);
        await prefs.remove(_keyStaffAdminSalt);
        currentRole = AdminRole.none;
        activeStaff = null;
        // Delete the key after use for security
        await resetFile.delete();

        await DatabaseHelper.instance.logSecurityEvent("SECURITY_RESET",
            "Admin PIN was cleared via physical Hardware Key.",
            severity: "CRITICAL");
        return true;
      }
    } catch (e) {
      debugPrint("Reset Check Error: $e");
    }
    return false;
  }
}
