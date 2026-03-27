import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../auth/models/user_model.dart';
import '../models/chat_message.dart';

import '../domain/i_chat_repository.dart';

/// Web-safe ChatRepository that uses Supabase directly.
/// No DatabaseHelper, sqflite, dart:io.
class WebChatRepository extends ChangeNotifier implements IChatRepository {
  final _supabase = Supabase.instance.client;
  final List<ChatMessage> _messages = [];
  final Map<String, bool> _onlineStatus = {};
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _presenceChannel;
  User? _selectedPatient;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  Map<String, bool> get onlineStatus => Map.unmodifiable(_onlineStatus);
  @override
  User? get selectedPatient => _selectedPatient;

  @override
  void setSelectedPatient(User? patient) {
    _selectedPatient = patient;
    if (patient != null) {
      initChat('admin', patient.id);
    }
    notifyListeners();
  }

  /// Initialize real-time listener for a specific chat between two users
  @override
  void initChat(String currentUserId, String otherUserId) {
    _messages.clear();
    _syncDownCloudMessages(currentUserId, otherUserId);
    _setupRealtime(currentUserId, otherUserId);
    _setupPresence(currentUserId);
  }

  Future<void> _syncDownCloudMessages(
      String currentUserId, String otherUserId) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .order('timestamp', ascending: true);

      final List<dynamic> data = response as List;
      _messages.clear();
      _messages.addAll(data.map((row) => ChatMessage.fromMap({...row, 'is_synced': 1})));
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // DESC
      notifyListeners();
    } catch (e) {
      debugPrint("☁️ Web Chat Sync Down Error: $e");
    }
  }

  void _setupRealtime(String currentUserId, String otherUserId) {
    _chatChannel?.unsubscribe();
    _retryTimer?.cancel();

    // 1. UNIQUE CHANNEL NAME per user lane
    final String channelName = 'chat_user_${currentUserId.replaceAll('-', '_')}';
    final channel = _supabase.channel(channelName);
    _chatChannel = channel;

    // 2. SERVER-SIDE FILTERS (Best practice for performance and security)
    // We listen specifically for messages received by the current user
    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'receiver_id',
        value: currentUserId,
      ),
      callback: (payload) => _onRealtimeChange(payload, currentUserId, otherUserId),
    ).onPostgresChanges(
      // Also listen for messages sent by the current user (e.g. from another device)
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'sender_id',
        value: currentUserId,
      ),
      callback: (payload) => _onRealtimeChange(payload, currentUserId, otherUserId),
    )
        .subscribe((status, [error]) {
      debugPrint("📡 Web Chat Realtime ($currentUserId): Status is $status");
      
      if (status == RealtimeSubscribeStatus.subscribed) {
        _retryCount = 0; // Reset on success
      }
      
      if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        if (error != null) debugPrint("❌ Realtime Error: $error");
        
        // 3. EXPONENTIAL BACKOFF
        _retryCount++;
        final int delaySeconds = (const Duration(seconds: 1) * (1 << (_retryCount.clamp(1, 6)))).inSeconds;
        debugPrint("🔄 Retrying Realtime subscription in ${delaySeconds}s (Attempt $_retryCount)...");
        
        _retryTimer = Timer(Duration(seconds: delaySeconds), () {
          _setupRealtime(currentUserId, otherUserId);
        });
      }
    });
  }

  void _onRealtimeChange(PostgresChangePayload payload, String currentUserId, String otherUserId) {
    final row = payload.newRecord;
    
    if (payload.eventType == PostgresChangeEvent.delete) {
      final deletedId = payload.oldRecord['id'];
      if (deletedId != null) {
        _messages.removeWhere((m) => m.id == deletedId);
        notifyListeners();
      }
      return;
    }

    final String? msgSenderId = row['sender_id'];
    final String? msgReceiverId = row['receiver_id'];

    // Ensure message belongs to the CURRENT conversation view
    final bool isRelevant = (msgSenderId == currentUserId && msgReceiverId == otherUserId) ||
                            (msgSenderId == otherUserId && msgReceiverId == currentUserId);

    if (!isRelevant) return;

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
    _handleIncomingMessage(msg);
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

  void _handleIncomingMessage(ChatMessage msg) {
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

    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // DESC
    notifyListeners();
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    // Optimistic local add
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      _messages.insert(0, message); // Latest at top for reversed list
    } else {
      _messages[index] = message;
    }
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // DESC
    notifyListeners();

    try {
      await _supabase.from('chat_messages').insert(message.toSupabaseMap());
    } catch (e) {
      debugPrint("❌ Web Chat Send Error: $e");
    }
  }

  @override
  Future<void> toggleReaction(
      String messageId, String userId, String emoji) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return;
    }

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

    final updatedMsg = msg.copyWith(reactions: reactions);
    _messages[index] = updatedMsg;
    notifyListeners();

    try {
      await _supabase.from('chat_messages').update({
        'reactions': reactions,
      }).eq('id', messageId);
    } catch (e) {
      debugPrint("⚠️ Web Reaction Error: $e");
    }
  }

  @override
  Future<void> forwardMessage(ChatMessage original, String targetUserId) async {
    final forwarded = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: original.senderId == 'admin' ? 'admin' : original.senderId,
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
    } catch (e) {
      debugPrint("Delete Message Error: $e");
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _chatChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
