import 'package:flutter/material.dart';

/// Mobile-optimized theme for the Patient Companion App.
/// Uses Google's Material 3 design language with custom brand colors.
class PatientAppTheme {
  static ThemeData get lightTheme {
    const brandGreen = Color(0xFF8CC63F); // Kiosk Primary Green
    const brandDark = Color(0xFF2D3142); // Kiosk Primary Dark
    const backgroundGrey = Color(0xFFF8FAFC); // Very Soft Background

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.light,
        primary: brandGreen,
        onPrimary: Colors.white,
        secondary: brandDark,
        tertiary: const Color(0xFF7CB335), // Darker Green
        surface: Colors.white,
        onSurface: brandDark,
        error: const Color(0xFFDC2626),
      ),

      // AppBar Theme - Matching Kiosk Style
      appBarTheme: const AppBarTheme(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: brandGreen,
        unselectedItemColor: Color(0xFF94A3B8),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 20,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: brandGreen.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        ),
      ),

      // Input Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      ),

      scaffoldBackgroundColor: backgroundGrey,

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 32,
      ),
    );
  }
}
