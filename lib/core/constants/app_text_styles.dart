import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Private constructor to prevent instantiation
  AppTextStyles._();

  // --- HEADLINES ---

  /// Massive text for "Welcome" or Main Menu titles
  static TextStyle get displayLarge => const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: AppColors.brandDark,
        letterSpacing: -1.5,
        height: 1.0,
      );

  /// Standard page titles (e.g., "Health History")
  static TextStyle get h1 => const TextStyle(
      fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.brandDark);

  /// Section headers (e.g., "Full Health Check")
  static TextStyle get h2 => const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        shadows: [
          Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black12),
        ],
      );

  // --- BODY TEXT ---

  /// Main instructions
  static TextStyle get bodyLarge => const TextStyle(
        fontSize: 24,
        color: Colors.grey,
        height: 1.5,
      );

  /// Standard labels
  static TextStyle get labelMedium => const TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brandDark);
}
