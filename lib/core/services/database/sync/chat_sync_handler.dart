import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'sync_handler.dart';
import '../../../../features/chat/models/chat_message.dart';

class ChatSyncHandler extends SyncHandler {
  ChatSyncHandler(super.supabase);

  @override
  Future<void> push() async {
    try {
      final blockedIds = await dbHelper.getBlockedRecords('chat_messages');
      final unsynced = await dbHelper.systemDao.getUnsyncedChatMessages();
      if (unsynced.isEmpty) {
        return;
      }

      final List<String> syncedIds = [];
      for (final row in unsynced) {
        if (blockedIds.contains(row['id'])) {
          continue;
        }

        try {
          final reactionsRaw = row['reactions'];
          Map<String, dynamic> reactions = {};
          if (reactionsRaw is String) {
            try {
              reactions = jsonDecode(reactionsRaw);
            } catch (_) {}
          } else if (reactionsRaw is Map) {
            reactions = Map<String, dynamic>.from(reactionsRaw);
          }

          final ChatMessage message = ChatMessage.fromMap({...row, 'reactions': reactions});
          
          // E2EE: Encrypt message content before pushing to Supabase
          final Map<String, dynamic> supabaseData = message.toSupabaseMap();
          supabaseData['content'] = dbHelper.encrypt(message.content);
          supabaseData['message'] = supabaseData['content']; // Redundant column support
          
          await supabase.from('chat_messages').upsert(supabaseData);
          syncedIds.add(row['id'] as String);
          await dbHelper.systemDao.clearSyncMetadata('chat_messages', row['id']);
        } catch (e) {
          await dbHelper.updateSyncMetadata(
            tableName: 'chat_messages',
            recordId: row['id'],
            error: e.toString(),
            incrementRetry: true,
          );
        }
      }

      if (syncedIds.isNotEmpty) {
        await dbHelper.markBatchAsSynced('chat_messages', syncedIds);
      }
    } catch (e) {
      debugPrint("❌ ChatSyncHandler: Push Error: $e");
    }
  }

  @override
  Future<void> pull() async {
    // Chat messages are usually pulled via Realtime or deliberate Fetch, 
    // but we can implement a delta-pull if needed for history sync.
    debugPrint("ℹ️ ChatSyncHandler: Pull (History Sync) not yet implemented.");
  }
}
