import 'package:flutter/foundation.dart';
import '../../../core/services/database/database_helper.dart';

class UsernameService {
  /// Generates the next sequential username in hYYXXXX format.
  /// YY: Last two digits of current year
  /// XXXX: 4-digit sequence
  static Future<String> generateNextUsername() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final yearSuffix = now.year.toString().substring(2);
      final pattern = 'h$yearSuffix%';

      // Find the highest sequence number for the current year
      final List<Map<String, dynamic>> result = await db.query(
        'patients',
        columns: ['username'],
        where: 'username LIKE ?',
        whereArgs: [pattern],
        orderBy: 'username DESC',
        limit: 1,
      );

      int nextSequence = 1;
      if (result.isNotEmpty) {
        final lastUsername = result.first['username'] as String;
        // Last 4 digits
        final lastSeqStr = lastUsername.substring(lastUsername.length - 4);
        final lastSeq = int.tryParse(lastSeqStr) ?? 0;
        nextSequence = lastSeq + 1;
      }

      final seqStr = nextSequence.toString().padLeft(4, '0');
      return 'h$yearSuffix$seqStr';
    } catch (e) {
      debugPrint("❌ Error generating username: $e");
      // Fallback to timestamp-based if DB fails (should not happen)
      return 'h${DateTime.now().millisecond}';
    }
  }
}
