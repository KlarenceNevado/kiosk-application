import 'package:flutter/material.dart';

/// Extension to allow dynamic Material Icon lookup from String names.
/// Useful for dynamic configuration from Supabase or JSON.
extension MaterialIconExtension on String {
  /// Converts a string name (e.g., 'home', 'person') to Material [IconData].
  /// Returns [Icons.help_outline] if the name is not found.
  IconData get toMaterialIcon {
    return _iconMap[toLowerCase()] ?? Icons.help_outline;
  }

  static const Map<String, IconData> _iconMap = {
    // --- COMMON ---
    'home': Icons.home,
    'person': Icons.person,
    'people': Icons.people,
    'settings': Icons.settings,
    'notifications': Icons.notifications,
    'notifications_active': Icons.notifications_active,
    'chat': Icons.chat,
    'message': Icons.message,
    'mail': Icons.mail,
    'calendar': Icons.calendar_today,
    'calendar_month': Icons.calendar_month,
    'history': Icons.history,
    'search': Icons.search,
    'info': Icons.info,
    'help': Icons.help,
    'warning': Icons.warning,
    'error': Icons.error,
    'check': Icons.check,
    'close': Icons.close,
    'add': Icons.add,
    'remove': Icons.remove,
    'delete': Icons.delete,
    'edit': Icons.edit,
    'save': Icons.save,
    'cloud': Icons.cloud,
    'sync': Icons.sync,
    'wifi': Icons.wifi,
    'battery': Icons.battery_full,

    // --- HEALTH SPECIFIC ---
    'health': Icons.health_and_safety,
    'monitor_heart': Icons.monitor_heart,
    'medical_services': Icons.medical_services,
    'favorite': Icons.favorite,
    'fitness': Icons.fitness_center,
    'thermometer': Icons.device_thermostat,
    'scale': Icons.scale,
    'blood_pressure': Icons.bloodtype,
    'oximeter': Icons.shutter_speed, // Using similar visual until specific found
    
    // --- KIOSK SPECIFIC ---
    'qr_code': Icons.qr_code,
    'print': Icons.print,
    'emergency': Icons.emergency,
    'announcement': Icons.campaign,
    'dashboard': Icons.dashboard,
    'security': Icons.security,
  };
}
