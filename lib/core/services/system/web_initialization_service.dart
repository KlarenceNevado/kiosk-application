import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_environment.dart';
import '../../errors/error_handler.dart';

/// Web-safe initialization service.
/// This service is used ONLY for the Patient Mobile PWA build.
/// It avoids all `dart:io` and native-only dependencies (sqflite, window_manager, etc).
class WebInitializationService {
  static final WebInitializationService _instance = WebInitializationService._internal();
  factory WebInitializationService() => _instance;
  WebInitializationService._internal();

  Future<void> initialize() async {
    final mode = AppEnvironment().mode;
    debugPrint("🚀 [WebInitializationService] Initializing for mode: $mode (Web)");

    // 1. Timezone
    _initTimezone();

    // 2. Error handling
    ErrorHandler.init();

    // 3. Load .env
    await _initDotEnv();

    // 4. Initialize Supabase (the SOLE data source on Web)
    await _initSupabase();

    debugPrint("✅ [WebInitializationService] Web initialization complete.");
  }

  void _initTimezone() {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (e) {
      debugPrint("⚠️ WebInitializationService (Timezone): $e");
    }
  }

  Future<void> _initDotEnv() async {
    try {
      await dotenv.load(fileName: "assets/.env").timeout(const Duration(seconds: 3));
      debugPrint("✅ WebInitializationService: Loaded assets/.env");
    } catch (e) {
      debugPrint("⚠️ WebInitializationService (DotEnv): $e");
    }
  }

  Future<void> _initSupabase() async {
    try {
      final supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '').isNotEmpty 
          ? const String.fromEnvironment('SUPABASE_URL') 
          : dotenv.env['SUPABASE_URL'];
          
      final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '').isNotEmpty 
          ? const String.fromEnvironment('SUPABASE_ANON_KEY') 
          : dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseUrl.isEmpty ||
          supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
        throw Exception("Missing SUPABASE_URL or SUPABASE_ANON_KEY dynamically injected");
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 5));
      debugPrint("✅ WebInitializationService: Supabase initialized");
    } catch (e) {
      debugPrint("❌ WebInitializationService (Supabase Critical): $e");
      rethrow;
    }
  }
}
