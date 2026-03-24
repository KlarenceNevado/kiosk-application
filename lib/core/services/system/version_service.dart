import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static const String _versionUrl = 'https://klarencenevado.github.io/kiosk-application/version.json';

  Future<bool> isUpdateAvailable() async {
    try {
      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final remoteVersion = data['version'] as String;
        final packageInfo = await PackageInfo.fromPlatform();
        final localVersion = packageInfo.version;
        return _isVersionNewer(localVersion, remoteVersion);
      }
    } catch (e) {
      // Fail silently, just means no update check
    }
    return false;
  }

  bool _isVersionNewer(String local, String remote) {
    if (local == remote) return false;
    
    // Simple semver snippet (major.minor.patch)
    try {
      List<int> localParts = local.split('+')[0].split('.').map(int.parse).toList();
      List<int> remoteParts = remote.split('+')[0].split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      
      // Check build number if versions are same
      if (remote.contains('+') && local.contains('+')) {
        int localBuild = int.parse(local.split('+')[1]);
        int remoteBuild = int.parse(remote.split('+')[1]);
        return remoteBuild > localBuild;
      }
    } catch (e) {
      return remote != local;
    }
    return false;
  }
}
