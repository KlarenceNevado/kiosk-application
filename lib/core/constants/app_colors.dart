import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color brandGreen = Color(0xFF8CC63F);
  static const Color brandGreenDark = Color(0xFF7CB335);
  static const Color brandGreenLight = Color(0xFFE9F5D8);
  static const Color brandDark = Color(0xFF2D3142);

  // UI Colors
  static const Color background = Colors.white;
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF888888);

  // Layout Colors (Required by MainMenu and Mobile)
  static const Color headerBackground = Color(0xFFF0F1F2);
  static const Color bodyBackground = Color(0xFFE6E6E6);

  // Sensor & Feedback Colors
  static const Color tempOrange = Color(0xFFFF9800);
  static const Color bpBlue = Color(0xFF2196F3);
  static const Color hrRed = Color(0xFFF44336);
  static const Color spO2Cyan = Color(0xFF00BCD4);

  // Premium Tokens
  static const List<Color> premiumGreenGradient = [
    Color(0xFF8CC63F),
    Color(0xFF7CB335),
    Color(0xFF5A8B24),
  ];

  static const Color glassWhite = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x4DFFFFFF);
  
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
