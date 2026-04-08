import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Private constructor to prevent instantiation
  AppTextStyles._();

  // --- HEADLINES ---

  /// Massive text for "Welcome" or Main Menu titles
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 38, // Reduced from 48
        fontWeight: FontWeight.w700, // Reduced from w900
        color: AppColors.brandDark,
        letterSpacing: -0.5,
      );

  /// Standard page titles (e.g., "Health History")
  static TextStyle get h1 => GoogleFonts.outfit(
        fontSize: 28, // Reduced from 32
        fontWeight: FontWeight.w700, // Reduced from w800
        color: AppColors.brandDark,
      );

  /// Section headers (e.g., "Full Health Check")
  static TextStyle get h2 => GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  // --- BODY TEXT ---

  /// Main instructions
  static TextStyle get bodyLarge => GoogleFonts.outfit(
        fontSize: 20,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      );

  /// Standard labels
  static TextStyle get labelMedium => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.brandDark,
      );
}
