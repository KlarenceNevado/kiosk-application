import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../auth/models/user_model.dart';
import '../models/chat_message.dart';

/// Web-safe ChatRepository that uses Supabase directly.
/// No DatabaseHelper, sqflite, dart:io.
class ChatRepository extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final List<ChatMessage> _messages = [];
  final Map<String, bool> _onlineStatus = {};
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _presenceChannel;
  User? _selectedPatient;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, bool> get onlineStatus => Map.unmodifiable(_onlineStatus);
  User? get selectedPatient => _selectedPatient;

  void setSelectedPatient(User? patient) {
    _selectedPatient = patient;
    if (patient != null) {
      initChat('admin', patient.id);
    }
    notifyListeners();
  }

  /// Initialize real-time listener for a specific chat between two users
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
          .eq('is_deleted', false)
          .order('timestamp', ascending: true);

      final List<dynamic> data = response as List;
      _messages.clear();
      _messages.addAll(data.map((row) => ChatMessage.fromMap({...row, 'is_synced': 1})));
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    } catch (e) {
      debugPrint("☁️ Web Chat Sync Down Error: $e");
    }
  }

  void _setupRealtime(String currentUserId, String otherUserId) {
    _chatChannel?.unsubscribe();

    late final RealtimeChannel channel;
    channel = _supabase.channel('public:chat_messages:$otherUserId');
    _chatChannel = channel;

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      callback: (payload) {
        final row = payload.newRecord;
        if (payload.eventType == PostgresChangeEvent.delete) {
          final deletedId = payload.oldRecord['id'];
          if (deletedId != null) {
            _messages.removeWhere((m) => m.id == deletedId);
            notifyListeners();
          }
          return;
        }

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

        if ((msg.senderId == currentUserId && msg.receiverId == otherUserId) ||
            (msg.senderId == otherUserId && msg.receiverId == currentUserId)) {
          _handleIncomingMessage(msg);
        }
      },
    )
        .subscribe((status, [error]) {
      debugPrint("📡 Web Chat Realtime ($otherUserId): Status is $status");
    });
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

    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  Future<void> sendMessage(ChatMessage message) async {
    // Optimistic local add
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();

    try {
      await _supabase.from('chat_messages').insert(message.toSupabaseMap());
    } catch (e) {
      debugPrint("❌ Web Chat Send Error: $e");
    }
  }

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
    _chatChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
