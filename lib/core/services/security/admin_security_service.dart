import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

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

  /// Checks if the provided PIN matches the stored secure PIN
  /// Returns the role associated with the PIN, or AdminRole.none if invalid
  Future<AdminRole> verifyPin(String inputPin) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedSuperHash = prefs.getString(_keyAdminPin);
    final String? storedStaffHash = prefs.getString(_keyStaffAdminPin);

    // If no Super Admin PIN is configured, something is wrong
    if (storedSuperHash == null) {
      debugPrint("Security Error: No Admin PIN Configured.");
      return AdminRole.none;
    }

    final superSalt = await _getOrGenerateSalt();
    final inputSuperHash = _hashPin(inputPin, superSalt);

    bool isSuperAdmin = _compareHashes(inputSuperHash, storedSuperHash);

    if (isSuperAdmin) {
      currentRole = AdminRole.superAdmin;
      return AdminRole.superAdmin;
    }

    // Checking Staff Admin
    if (storedStaffHash != null) {
      final staffSalt = prefs.getString(_keyStaffAdminSalt) ??
          superSalt; // fallback if missing
      final inputStaffHash = _hashPin(inputPin, staffSalt);
      bool isStaffAdmin = _compareHashes(inputStaffHash, storedStaffHash);

      if (isStaffAdmin) {
        currentRole = AdminRole.staffAdmin;
        return AdminRole.staffAdmin;
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
