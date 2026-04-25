import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:sqflite/sqflite.dart';
import '../../../core/services/database/database_helper.dart';
import '../../auth/models/user_model.dart';
import '../models/chat_message.dart';

import '../domain/i_chat_repository.dart';
import '../../../core/services/security/encryption_service.dart';

class LocalChatRepository extends ChangeNotifier implements IChatRepository {
  final _supabase = Supabase.instance.client;
  final List<ChatMessage> _messages = [];
  final Map<String, bool> _onlineStatus = {};
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _presenceChannel;
  User? _selectedResident;
  int _totalUnreadCount = 0;
  final Map<String, int> _unreadCounts = {};
  final Map<String, DateTime> _latestMessageTimes = {};

  LocalChatRepository() {
    _refreshUnreadCounts();
  }

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  Map<String, bool> get onlineStatus => Map.unmodifiable(_onlineStatus);
  @override
  User? get selectedResident => _selectedResident;

  @override
  void setSelectedResident(User? resident) {
    _selectedResident = resident;
    if (resident != null) {
      markAsRead(resident.id);
      initChat('admin', resident.id);
    }
    notifyListeners();
  }

  @override
  int getUnreadCount(String? userId) {
    if (userId == null) return _totalUnreadCount;
    return _unreadCounts[userId] ?? 0;
  }

  @override
  DateTime? getLatestMessageTime(String userId) {
    return _latestMessageTimes[userId];
  }

  @override
  Future<void> markAsRead(String otherUserId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'chat_messages',
        {'is_read': 1},
        where: 'sender_id = ? AND receiver_id = ? AND is_read = 0',
        whereArgs: [otherUserId, 'admin'],
      );

      // Also update in-memory messages if this is the active chat
      if (_selectedResident?.id == otherUserId) {
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].senderId == otherUserId && !_messages[i].isRead) {
            _messages[i] = _messages[i].copyWith(isRead: true);
          }
        }
      }

      await _refreshUnreadCounts();
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error marking as read: $e");
    }
  }

  Future<void> _refreshUnreadCounts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Total unread
      final totalResult = await db.rawQuery(
          "SELECT COUNT(*) as count FROM chat_messages WHERE receiver_id = 'admin' AND is_read = 0");
      _totalUnreadCount = Sqflite.firstIntValue(totalResult) ?? 0;

      // Per-user unread
      final perUserResult = await db.rawQuery(
          "SELECT sender_id, COUNT(*) as count FROM chat_messages WHERE receiver_id = 'admin' AND is_read = 0 GROUP BY sender_id");
      
      _unreadCounts.clear();
      for (var row in perUserResult) {
        final senderId = row['sender_id'] as String;
        final count = row['count'] as int;
        _unreadCounts[senderId] = count;
      }

      // Latest message times for sorting
      final latestResult = await db.rawQuery(
          "SELECT patient_id, MAX(timestamp) as last_time FROM chat_messages GROUP BY patient_id");
      
      _latestMessageTimes.clear();
      for (var row in latestResult) {
        final residentId = row['patient_id'] as String?;
        final lastTime = row['last_time'] as String?;
        if (residentId != null && lastTime != null) {
          _latestMessageTimes[residentId] = DateTime.parse(lastTime);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error refreshing unread counts: $e");
    }
  }

  /// Initialize real-time listener for a specific chat between two users
  @override
  void initChat(String currentUserId, String otherUserId) {
    _messages.clear();
    _refreshUnreadCounts(); // Load badges on startup
    _loadLocalMessages(currentUserId, otherUserId);
    _syncDownCloudMessages(currentUserId, otherUserId);
    _setupRealtime(currentUserId, otherUserId);
    _setupPresence(currentUserId);
  }

  Future<void> _loadLocalMessages(
      String currentUserId, String otherUserId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where:
          '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [currentUserId, otherUserId, otherUserId, currentUserId],
      orderBy: 'timestamp ASC',
    );

    _messages.clear();
    _messages.addAll(maps.map((m) => ChatMessage.fromMap(m)));
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // DESC
    notifyListeners();
  }

  Future<void> _syncDownCloudMessages(
      String currentUserId, String otherUserId) async {
    try {
      // Fetch history between these two users
      final response = await _supabase
          .from('chat_messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .eq('is_deleted', false)
          .order('timestamp', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        for (final row in data) {
          final msg = ChatMessage.fromMap({...row, 'is_synced': 1});
          // Avoid duplicates in memory and update local DB
          final index = _messages.indexWhere((m) => m.id == msg.id);

          if (index != -1) {
            _messages[index] = msg;
          } else if (!msg.isDeleted) {
            _messages.add(msg);
          }

          await db.insert('chat_messages', msg.toMap()..['is_synced'] = 1,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // DESC
        notifyListeners();
      }
    } catch (e) {
      debugPrint("☁️ Sync Down Error: $e");
    }
  }

  void _setupRealtime(String currentUserId, String otherUserId) {
    _chatChannel?.unsubscribe();
    _chatChannel = null;

    final String channelName =
        'public:chat_user_${currentUserId.replaceAll('-', '_')}';
    final channel = _supabase.channel(channelName);
    _chatChannel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          // FILTER: Current user is the receiver (new incoming messages)
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: currentUserId,
          ),
          callback: (payload) =>
              _onRealtimeChange(payload, currentUserId, otherUserId),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          // FILTER: Current user is the sender (for reaction/status updates sync)
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: currentUserId,
          ),
          callback: (payload) =>
              _onRealtimeChange(payload, currentUserId, otherUserId),
        )
        .subscribe((status, [error]) {
      debugPrint("📡 Chat Realtime ($currentUserId): Status is $status");
      if (error != null) {
        debugPrint("❌ Chat Realtime Error: $error");
      }
    });
  }

  void _onRealtimeChange(PostgresChangePayload payload, String currentUserId,
      String otherUserId) async {
    final row = payload.newRecord;
    if (payload.eventType == PostgresChangeEvent.delete) {
      final deletedId = payload.oldRecord['id'];
      if (deletedId != null) {
        _messages.removeWhere((m) => m.id == deletedId);
        notifyListeners();
      }
      return;
    }

    // Merge new record with existing local record
    final existingIndex = _messages.indexWhere((m) => m.id == row['id']);
    Map<String, dynamic> fullData;
    if (existingIndex != -1) {
      fullData = {
        ..._messages[existingIndex].toMap(),
        ...row,
        'is_synced': 1,
      };
    } else {
      fullData = {
        ...row,
        'is_synced': 1,
      };
    }

    final msg = ChatMessage.fromMap(fullData);

    // Final client-side filter for THIS conversation view
    final bool isRelevant =
        (msg.senderId == currentUserId && msg.receiverId == otherUserId) ||
            (msg.senderId == otherUserId && msg.receiverId == currentUserId);

    if (isRelevant) {
      _handleIncomingMessage(msg);
    } else if (msg.receiverId == currentUserId) {
      // New message for another user, just update badges
      _refreshUnreadCounts();
    }
  }

  void _setupPresence(String userId) {
    _presenceChannel?.unsubscribe();

    _presenceChannel = _supabase.channel('online-users');

    _presenceChannel!.onPresenceSync((payload) {
      final newState = _presenceChannel!.presenceState();
      _onlineStatus.clear();
      for (final state in newState) {
        final presences = (state as dynamic).presences as List;
        if (presences.isNotEmpty) {
          final uid = presences.first.payload['user_id'] as String?;
          if (uid != null) {
            _onlineStatus[uid] = true;
          }
        }
      }
      notifyListeners();
    }).subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({'user_id': userId});
      }
    });
  }

  void _handleIncomingMessage(ChatMessage msg) async {
    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      if (msg.isDeleted) {
        _messages.removeAt(index);
      } else {
        _messages[index] = msg;
      }
    } else if (!msg.isDeleted) {
      _messages.add(msg);
    }

    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _refreshUnreadCounts(); // Update latest message times for sorting
    notifyListeners();

    // Persist locally
    final db = await DatabaseHelper.instance.database;
    if (msg.isDeleted) {
      await db.delete('chat_messages', where: 'id = ?', whereArgs: [msg.id]);
    } else {
      await db.insert('chat_messages', msg.toMap()..['is_synced'] = 1,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (msg.receiverId == 'admin' && !msg.isRead) {
      if (_selectedResident?.id == msg.senderId) {
        markAsRead(msg.senderId);
      } else {
        await _refreshUnreadCounts();
      }
    } else {
      // Refresh to update latest message times for sorting even if already read or sent by me
      await _refreshUnreadCounts();
    }
    notifyListeners();
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    // 1. Add locally first for instant feedback
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _refreshUnreadCounts(); // Update latest message times for sorting
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'chat_messages',
        message.toMap()..['is_synced'] = 0,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Upload to Supabase (Best effort)
      try {
        final encryptedMap = message.toSupabaseMap();
        // Encrypt content before pushing to cloud
        if (encryptedMap['content'] != null &&
            !encryptedMap['content'].toString().startsWith('http')) {
          encryptedMap['content'] =
              EncryptionService().encryptData(encryptedMap['content']);
          encryptedMap['message'] = encryptedMap['content'];
        }

        await _supabase.from('chat_messages').insert(encryptedMap);

        // 3. Mark as synced
        await db.update(
          'chat_messages',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [message.id],
        );

        final updatedIdx = _messages.indexWhere((m) => m.id == message.id);
        if (updatedIdx != -1) {
          _messages[updatedIdx] = message.copyWith(isSynced: true);
          notifyListeners();
        }
      } catch (e) {
        debugPrint(
            "⚠️ Chat Cloud Push failed: $e. Message saved locally for background sync.");
        // We don't throw here, as it's saved locally and SyncService will pick it up.
      }
    } catch (e) {
      debugPrint("❌ Critical Chat Save Error: $e");
    }
  }

  @override
  Future<void> toggleReaction(
      String messageId, String userId, String emoji) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final msg = _messages[index];
    final reactions = Map<String, List<String>>.from(msg.reactions);

    final reactors = reactions[emoji] ?? [];
    if (reactors.contains(userId)) {
      reactors.remove(userId);
    } else {
      reactors.add(userId);
    }

    if (reactors.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = reactors;
    }

    // Optimistic local and DB update
    final updatedMsg = msg.copyWith(reactions: reactions);
    _messages[index] = updatedMsg;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'chat_messages',
        {'reactions': jsonEncode(reactions), 'is_synced': 0},
        where: 'id = ?',
        whereArgs: [messageId],
      );

      // Try Cloud push
      try {
        await _supabase.from('chat_messages').update({
          'reactions': reactions,
        }).eq('id', messageId);

        // Mark as synced if successful
        await db.update(
          'chat_messages',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [messageId],
        );
      } catch (e) {
        debugPrint(
            "⚠️ Reaction Cloud update failed: $e. Saved locally for background sync.");
      }
    } catch (e) {
      debugPrint("❌ Reaction Error: $e");
    }
  }

  @override
  Future<void> forwardMessage(ChatMessage original, String targetUserId) async {
    // Note: original.content is already decrypted by fromMap when loaded
    final forwarded = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'admin', // Or current user ID
      receiverId: targetUserId,
      content: original.content,
      timestamp: DateTime.now(),
      isForwarded: true,
      updatedAt: DateTime.now(),
    );
    await sendMessage(forwarded);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase.from('chat_messages').delete().eq('id', messageId);

      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();

      final db = await DatabaseHelper.instance.database;
      await db.delete('chat_messages', where: 'id = ?', whereArgs: [messageId]);
    } catch (e) {
      debugPrint("Delete Message Error: $e");
    }
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
