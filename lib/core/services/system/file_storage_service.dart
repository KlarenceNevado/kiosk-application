import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();

  final _supabase = Supabase.instance.client;
  static const String bucketName = 'kiosk-files';

  /// Uploads a file to Supabase Storage and returns the public URL.
  Future<String?> uploadFile(File file, String bucket, {String? remotePath}) async {
    try {
      final fileName = p.basename(file.path);
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
      // On web, we don't have a local filesystem to 'cache' an actual File object.
      // We return the URL and let the browser handle it.
      return null; // Return null so the caller uses the URL, or return the URL if the caller can handle it.
    }

    try {
      // 1. Check local path hint if provided
      if (localPathHint != null) {
        final hintFile = File(localPathHint);
        if (await hintFile.exists()) {
          return hintFile;
        }
      }

      // 2. Resolve local path from URL
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      final cacheDir = await getApplicationDocumentsDirectory();
      final localFile = File('${cacheDir.path}/cache/$fileName');

      // 3. Return local if exists
      if (await localFile.exists()) {
        return localFile;
      }

      // 4. Download and cache
      debugPrint("⬇️ Downloading file for cache: $url");
      final response = await HttpClient().getUrl(uri).then((req) => req.close());
      if (response.statusCode == 200) {
        await localFile.parent.create(recursive: true);
        final bytes = await consolidateHttpClientResponseBytes(response);
        await localFile.writeAsBytes(bytes);
        debugPrint("✅ File cached locally: ${localFile.path}");
        return localFile;
      }

      return null;
    } catch (e) {
      debugPrint("⚠️ File caching error: $e");
      return null;
    }
  }

  /// Systematic background caching of a list of URLs.
  Future<void> prefetchFiles(List<String> urls) async {
    if (kIsWeb) return; // Browsers handle their own caching via Service Workers/Cache API

    for (final url in urls) {
      await getCachedFile(url);
    }
  }
}
