// ignore_for_file: avoid_print
// Removed unused import
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  const dbPath =
      "C:\\Users\\Klarence Nevado\\AppData\\Roaming\\com.example\\kiosk_application\\kiosk_health.db";
  final db = await dbFactory.openDatabase(dbPath);

  // Verified Credentials
  const url = "https://zumghuyvofohqbxgnnmf.supabase.co";
  const key =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1bWdodXl2b2ZvaHFieGdubm1mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0NDE3NTIsImV4cCI6MjA4ODAxNzc1Mn0.n1a0PXVvDhGvXKmHrSm6wdaxYVNnHXktp_D82JmPets";

  final headers = {
    'apikey': key,
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  print("🚀 Starting Definitive Sync (Direct HTTP)...");

  // 1. Get Unsynced Vitals
  final unsynced = await db.query('vitals', where: 'is_synced = 0');
  if (unsynced.isEmpty) {
    print("✅ No unsynced vitals found.");
    await db.close();
    return;
  }

  for (var row in unsynced) {
    final userId = row['user_id'].toString();
    print("\n📦 Processing Vital for User: $userId");

    // A. Check/Push Patient
    final pCheckRes = await http.get(
        Uri.parse("$url/rest/v1/patients?id=eq.$userId&select=*"),
        headers: headers);
    if (pCheckRes.statusCode == 200 && jsonDecode(pCheckRes.body).isEmpty) {
      print("⚠️ Patient $userId missing in cloud. Pushing...");
      final pLocal =
          await db.query('patients', where: 'id = ?', whereArgs: [userId]);
      if (pLocal.isNotEmpty) {
        final pData = Map<String, dynamic>.from(pLocal.first);
        final pPayload = {
          'id': pData['id'],
          'first_name': pData['first_name'],
          'last_name': pData['last_name'],
          'date_of_birth': pData['date_of_birth'],
          'phone_number': pData['phone_number'],
          'pin_code': pData['pin_code']?.toString(),
          'sitio': pData['sitio'],
        };
        final pPushRes = await http.post(Uri.parse("$url/rest/v1/patients"),
            headers: headers, body: jsonEncode(pPayload));
        if (pPushRes.statusCode == 201 || pPushRes.statusCode == 200) {
          print("  ✅ Patient pushed.");
        } else {
          print(
              "  ❌ Patient push failed: ${pPushRes.statusCode} - ${pPushRes.body}");
          continue;
        }
      }
    } else if (pCheckRes.statusCode == 200) {
      print("  ✅ Patient exists in cloud.");
    } else {
      print(
          "  ❌ Patient check failed: ${pCheckRes.statusCode} - ${pCheckRes.body}");
      continue;
    }

    // B. Push Vital
    final vPayload = {
      'id': row['id'],
      'user_id': userId,
      'timestamp': row['timestamp'],
      'heart_rate': row['heart_rate'].toString(),
      'systolic_bp': row['systolic_bp'].toString(),
      'diastolic_bp': row['diastolic_bp'].toString(),
      'oxygen': row['oxygen'].toString(),
      'temperature': row['temperature'].toString(),
      'bmi': row['bmi'] is num
          ? row['bmi']
          : double.tryParse(row['bmi'].toString()) ?? 0.0,
      'status': row['status'] ?? 'pending',
      'remarks': row['remarks'],
      'report_url': row['report_url'],
    };

    final vPushRes = await http.post(Uri.parse("$url/rest/v1/vitals"),
        headers: headers..addAll({'Prefer': 'resolution=merge-duplicates'}),
        body: jsonEncode(vPayload));
    if (vPushRes.statusCode == 201 ||
        vPushRes.statusCode == 204 ||
        vPushRes.statusCode == 200) {
      print("✅ Vital ${row['id']} synced successfully!");
      await db.update('vitals', {'is_synced': 1},
          where: 'id = ?', whereArgs: [row['id']]);
    } else {
      print("❌ Vital sync failed: ${vPushRes.statusCode} - ${vPushRes.body}");
    }
  }

  await db.close();
  print("\n🏁 Sync complete.");
}
