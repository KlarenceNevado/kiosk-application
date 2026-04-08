import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_handler.dart';
import '../../../../features/chat/models/chat_message.dart';
import '../../security/notification_service.dart';

class ChatSyncHandler extends SyncHandler {
  ChatSyncHandler(super.supabase, [super.db]);

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

          final ChatMessage message =
              ChatMessage.fromMap({...row, 'reactions': reactions});

          // E2EE: Encrypt message content before pushing to Supabase
          final Map<String, dynamic> supabaseData = message.toSupabaseMap();
          supabaseData['content'] = dbHelper.encrypt(message.content);
          supabaseData['message'] =
              supabaseData['content']; // Redundant column support

          await supabase.from('chat_messages').upsert(supabaseData);
          syncedIds.add(row['id']?.toString() ?? '');
          await dbHelper.systemDao
              .clearSyncMetadata('chat_messages', row['id']);
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
  Future<void> pull([String? userId]) async {
    final currentUserId = userId ?? supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      debugPrint("ℹ️ ChatSyncHandler: No active session. Skipping pull.");
      return;
    }

    try {
      final lastSync = await _getLastSync();

      // SECURITY: Enforce participant filter in the query itself (Defense in depth)
      var query = supabase
          .from('chat_messages')
          .select()
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');

      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudData = await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      for (var row in cloudData) {
        final exists = await dbHelper.systemDao.getChatMessageById(row['id']);
        if (exists == null) {
          final msg = ChatMessage.fromMap(row);

          // Only notify if someone ELSE sent the message
          if (msg.senderId != currentUserId) {
            String senderName = "Health Worker";
            final patient =
                await dbHelper.patientDao.getPatientById(msg.senderId);
            if (patient != null) {
              senderName = "${patient.firstName} ${patient.lastName}";
            }

            final int notificationId = msg.senderId.hashCode.abs() % 10000;
            NotificationService().showChatNotification(
              senderName: senderName,
              message: msg.content,
              notificationId: notificationId,
            );
          }
        }

        await dbHelper.systemDao.upsertChatMessage(row);
        latestTimestamp = row['updated_at'];
      }

      if (latestTimestamp != null) {
        await _updateLastSync(latestTimestamp);
      }
    } catch (e) {
      debugPrint("❌ ChatSyncHandler: Pull Error: $e");
    }
  }

  Future<String?> _getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_chat_messages');
  }

  Future<void> _updateLastSync(String? timestamp) async {
    if (timestamp == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_chat_messages', timestamp);
  }

  RealtimeChannel? _channel;
  void subscribe([String? userId]) {
    if (_channel != null) return;

    final currentUserId = userId ?? supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      debugPrint("⚠️ ChatSyncHandler: No active session. Realtime disabled.");
      return;
    }

    final String channelName =
        'public:chat_sync_${currentUserId.replaceAll('-', '_')}';
    _channel = supabase.channel(channelName);

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: currentUserId,
          ),
          callback: (payload) async {
            if (payload.newRecord.isNotEmpty &&
                payload.eventType == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              if (row['receiver_id'] == currentUserId) {
                // Background pull to refresh local DB & Notify
                unawaited(pull(currentUserId));
              }
            }
          },
        )
        .subscribe();

    debugPrint("📡 ChatSyncHandler: Realtime Subscribed for $currentUserId");
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
