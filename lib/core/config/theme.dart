import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        brightness: Brightness.light,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // Consistent Text Styling
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
        displayLarge: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900, // Black
            color: AppColors.brandDark,
            letterSpacing: -1.0),
        headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800, // ExtraBold
            color: AppColors.brandDark,
            letterSpacing: -0.5),
        bodyLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.brandDark,
            height: 1.5),
        labelLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5), // For buttons
      )),

      // Global Button Styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: Colors.white,
          elevation: 0, // We use custom shadows elsewhere or rely on Material 3
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),

      // Fluid Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Hide Scrollbars for Kiosk UI
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(false),
        trackVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(0),
        interactive: false,
      ),
    );
  }
}
