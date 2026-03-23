import 'package:flutter/material.dart';

/// Shared language toggle provider used by both the Kiosk and Patient apps.
/// Extracted here to avoid cross-main-file imports.
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void toggleLanguage() {
    _locale =
        _locale.languageCode == 'en' ? const Locale('fil') : const Locale('en');
    notifyListeners();
  }
}
