import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';

abstract class SyncHandler {
  final SupabaseClient supabase;
  final DatabaseHelper dbHelper;

  SyncHandler(this.supabase, [DatabaseHelper? db])
      : dbHelper = db ?? DatabaseHelper.instance;

  /// Standardized push logic (Local -> Cloud)
  Future<void> push();

  /// Standardized pull logic (Cloud -> Local)
  Future<void> pull();
}
