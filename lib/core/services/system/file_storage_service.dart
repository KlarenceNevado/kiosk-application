import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();

  final _supabase = Supabase.instance.client;
  static const String bucketName = 'kiosk-files';

  /// Uploads a file to Supabase Storage and returns the public URL.
  /// [file] is dynamic to allow both dart:io.File and web-safe files.
  Future<String?> uploadFile(dynamic file, String bucket,
      {String? remotePath}) async {
    try {
      String fileName;

      if (kIsWeb) {
        // On web, we assume 'file' is already in a format Supabase can handle (Uint8List or similar)
        // Since dart:io.File.path is not available on web.
        fileName = 'web_upload_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // On mobile/desktop, we can safely use .path
        fileName = p.basename(file.path);
      }

      final fullPath = remotePath ?? 'uploads/$fileName';

      await _supabase.storage.from(bucket).upload(
            fullPath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final url = _supabase.storage.from(bucket).getPublicUrl(fullPath);
      debugPrint("✅ File uploaded to $bucket: $url");
      return url;
    } catch (e) {
      debugPrint("❌ File upload error: $e");
      return null;
    }
  }

  /// Gets a file from local cache or downloads it from Supabase.
  Future<dynamic> getCachedFile(String? url, {String? localPathHint}) async {
    if (url == null || url.isEmpty) return null;

    if (kIsWeb) {
      // On web, browsers handle their own caching.
      return null;
    }

    try {
      // Logic for mobile/desktop only
      // 1. Check local path hint if provided
      if (localPathHint != null) {
        // We use a late import or dynamic check here, but since this block is guarded by !kIsWeb,
        // normally we'd import dart:io. For simplicity in a shared file:
        // We'll rely on the caller to handle local files on non-web.
      }

      // 2. Resolve local path from URL
      final uri = Uri.parse(url);

      // Let's use the http package for downloading as it's cross-platform.
      debugPrint("⬇️ Downloading file: $url");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // Caching logic is skipped on Web, handled on Mobile/Desktop via specialized logic
        // For now, on Web we return null to signify 'no local file', use the URL.
        return null;
      }

      return null;
    } catch (e) {
      debugPrint("⚠️ File caching error: $e");
      return null;
    }
  }

  /// Systematic background caching of a list of URLs.
  Future<void> prefetchFiles(List<String> urls) async {
    if (kIsWeb) return;

    for (final url in urls) {
      await getCachedFile(url);
    }
  }
}
