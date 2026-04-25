import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
// No extra import needed, just fixing the enum name.
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
  User? _selectedResident;
  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _pollingTimer;
  String? _activeCurrentUserId;
  String? _activeOtherUserId;
  bool _isRealtimeOperational = false;

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
    // Basic implementation for Web if needed
    return 0; 
  }

  @override
  DateTime? getLatestMessageTime(String userId) {
    return null;
  }

  @override
  void markAsRead(String otherUserId) {
    // Implementation for Web if needed
  }

  /// Initialize real-time listener for a specific chat between two users
  @override
  void initChat(String currentUserId, String otherUserId) {
    if (_activeCurrentUserId == currentUserId &&
        _activeOtherUserId == otherUserId &&
        _chatChannel != null) {
      debugPrint(
          "ℹ️ Web Chat: Already initialized for $currentUserId <-> $otherUserId");
      return;
    }

    _activeCurrentUserId = currentUserId;
    _activeOtherUserId = otherUserId;
    _retryCount = 0;
    _isRealtimeOperational = false;

    _messages.clear();
    _stopPolling(); // Stop any existing fallback
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
      _messages.addAll(
          data.map((row) => ChatMessage.fromMap({...row, 'is_synced': 1})));
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // DESC
      notifyListeners();
    } catch (e) {
      debugPrint("☁️ Web Chat Sync Down Error: $e");
    }
  }

  void _setupRealtime(String currentUserId, String otherUserId) async {
    if (_chatChannel != null) {
      await _chatChannel!.unsubscribe();
      _chatChannel = null;
    }
    _retryTimer?.cancel();

    // Diagnostic: Log Session State
    final session = _supabase.auth.currentSession;
    debugPrint(
        "🔐 Supabase Session: ${session == null ? 'ANON' : 'ACTIVE'} (User: ${session?.user.id})");

    // 1. UNIQUE CHANNEL NAME (Using 'public:' prefix for better anon compatibility)
    final String channelName =
        'public:chat_user_${currentUserId.replaceAll('-', '_')}';
    final channel = _supabase.channel(channelName);
    _chatChannel = channel;

    // 2. BROAD LISTENERS but ENFORCED FILTERS (Security layer on top of RLS)
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
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
          // For updates/deletes we can't easily filter by receiver_id only if they are sender.
          // But RLS will catch it. We add this second listener for self-sent message sync if needed.
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: currentUserId,
          ),
          callback: (payload) =>
              _onRealtimeChange(payload, currentUserId, otherUserId),
        )
        .onBroadcast(
          // 3. BROADCAST SIGNAL (Immediate "New Message" ping)
          event: 'new_message',
          callback: (payload) {
            debugPrint("🔔 Web Chat: Received Broadcast new_message.");
            _syncDownCloudMessages(currentUserId, otherUserId);
          },
        )
        .subscribe((status, [error]) {
      // Only log first status change to reduce noise
      if (_retryCount == 0) {
        debugPrint("📡 Web Chat Realtime: $status");
      }

      if (status == RealtimeSubscribeStatus.subscribed) {
        _retryCount = 0;
        _isRealtimeOperational = true;
        _stopPolling();
        debugPrint("✅ Web Chat: Realtime Operational.");
      }

      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        _isRealtimeOperational = false;
        _retryCount++;

        // Start polling immediately
        _startPolling(currentUserId, otherUserId, interval: 3);

        // CAP RETRIES: After 5 failures, give up on Realtime entirely
        if (_retryCount >= 5) {
          debugPrint(
              "🛑 Web Chat: WebSocket unavailable. Using REST polling only.");
          _chatChannel?.unsubscribe();
          _chatChannel = null;
          return;
        }

        final int delaySeconds =
            (const Duration(seconds: 1) * (1 << (_retryCount.clamp(1, 4))))
                .inSeconds;
        debugPrint("🔄 Realtime retry $_retryCount/5 in ${delaySeconds}s...");

        _retryTimer = Timer(Duration(seconds: delaySeconds), () {
          _setupRealtime(currentUserId, otherUserId);
        });
      }
    });
  }

  int _pollCount = 0;
  int _activePollingInterval = 0;

  void _startPolling(String currentUserId, String otherUserId,
      {int interval = 10}) {
    // Skip if already polling at this interval
    if (_pollingTimer != null && _activePollingInterval == interval) return;

    // If interval changed, restart
    _pollingTimer?.cancel();
    _pollingTimer = null;

    _activePollingInterval = interval;
    debugPrint("⚡ Web Chat: REST polling active (${interval}s).");
    _pollingTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!_isRealtimeOperational) {
        _pollCount++;
        if (_pollCount % 20 == 1) {
          debugPrint("⏱️ Web Chat: Poll #$_pollCount...");
        }
        _syncDownCloudMessages(currentUserId, otherUserId);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _onRealtimeChange(
      PostgresChangePayload payload, String currentUserId, String otherUserId) {
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
    final bool isRelevant =
        (msgSenderId == currentUserId && msgReceiverId == otherUserId) ||
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

  void _setupPresence(String userId) async {
    if (_presenceChannel != null) {
      await _presenceChannel!.unsubscribe();
      _presenceChannel = null;
    }

    // Using 'public:' prefix for better compatibility with anon roles
    _presenceChannel = _supabase.channel('public:online-users');

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

      // 5. BROADCAST NOTIFICATION (Optional: Speed-up signal)
      // _chatChannel?.send(type: RealtimeListenTypes.broadcast, event: 'new_message', payload: {'id': message.id});
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
    _stopPolling();
    _retryTimer?.cancel();
    _chatChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
