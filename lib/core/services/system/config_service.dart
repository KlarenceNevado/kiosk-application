import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  // Keys
  static const String _keyServerIp = 'config_server_ip';
  static const String _keyFacilityName = 'config_facility_name';

  // Defaults
  String _serverIp =
      "https://127.0.0.1:8090"; // Localhost default for Windows testing
  String _facilityName = "Isla Verde Health Station";

  // Getters
  String get serverIp => _serverIp;
  String get facilityName => _facilityName;

  /// Helper to enforce https on IPs
  String _enforceHttps(String ip) {
    if (ip.startsWith("http://")) {
      return ip.replaceFirst("http://", "https://");
    } else if (!ip.startsWith("https://")) {
      return "https://$ip";
    }
    return ip;
  }

  /// Load settings from disk on app start
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Ensure fresh data
    _serverIp = prefs.getString(_keyServerIp) ?? _serverIp;

    // AUTO-FIX: Enforce HTTPS globally
    _serverIp = _enforceHttps(_serverIp);

    // AUTO-FIX: Remove trailing '/_/' or '/' if user copied the admin link
    if (_serverIp.endsWith('/_/') || _serverIp.endsWith('/')) {
      _serverIp = _serverIp.replaceAll('/_/', '').replaceAll(RegExp(r'/$'), '');
    }

    // Attempt to persist the auto-fixes if any happened
    await prefs.setString(_keyServerIp, _serverIp);

    _facilityName = prefs.getString(_keyFacilityName) ?? _facilityName;
  }

  /// Save new settings
  Future<void> updateSettings({String? ip, String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    if (ip != null) {
      final secureIp = _enforceHttps(ip);
      _serverIp = secureIp;
      await prefs.setString(_keyServerIp, secureIp);
    }
    if (name != null) {
      _facilityName = name;
      await prefs.setString(_keyFacilityName, name);
    }
  }
}
