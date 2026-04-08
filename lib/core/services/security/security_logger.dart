import 'package:flutter/foundation.dart';

/// Centralized security logger that automatically masks PII (Personally Identifiable Information).
/// Use this instead of debugPrint/print for any logs that might contain patient data.
class SecurityLogger {
  /// Masks a string (e.g., "Juan Dela Cruz" -> "J*** D*** C***")
  static String maskPII(String? input) {
    if (input == null || input.isEmpty) return "N/A";

    // If it's a phone number (mostly digits)
    if (RegExp(r'^[0-9+ ]+$').hasMatch(input)) {
      if (input.length <= 4) return "****";
      return "${input.substring(0, 2)}*******${input.substring(input.length - 2)}";
    }

    // If it's a name (handle multiple words)
    return input.split(' ').map((word) {
      if (word.length <= 1) return word;
      if (word.length == 2) return "${word[0]}*";
      return "${word[0]}${'*' * (word.length - 1)}";
    }).join(' ');
  }

  static void info(String message, {String? pii}) {
    final sanitizedMessage = pii != null ? "$message ${maskPII(pii)}" : message;
    _internalLog("INFO", sanitizedMessage);
  }

  static void warning(String message, {String? pii}) {
    final sanitizedMessage = pii != null ? "$message ${maskPII(pii)}" : message;
    _internalLog("WARNING", sanitizedMessage);
  }

  static void error(String message, {Object? error, StackTrace? stack}) {
    // Errors are logged fully in debug, but sanitized in release if we were using a cloud logger
    _internalLog("ERROR", message);
    if (error != null) debugPrint("   Details: $error");
    if (stack != null) debugPrint("   Stack: $stack");
  }

  static void _internalLog(String level, String message) {
    // In a real production app, we would strip these entirely or send to a secure private sink (like Sentry/Firebase)
    // For this Kiosk, we allow console logging but enforce maskPII.
    final timestamp =
        DateTime.now().toIso8601String().split('T').last.substring(0, 12);
    debugPrint("[$timestamp] [$level] $message");
  }
}
