import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final String? replyTo;
  final Map<String, List<String>> reactions;
  final bool isDeleted;
  final DateTime updatedAt;
  final bool isForwarded;
  final bool isSynced;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.replyTo,
    this.reactions = const {},
    this.isDeleted = false,
    this.isForwarded = false,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Handle reactions from JSONB
    Map<String, List<String>> parsedReactions = {};
    if (map['reactions'] != null) {
      final dynamic rawReactions = map['reactions'] is String
          ? jsonDecode(map['reactions'])
          : map['reactions'];

      if (rawReactions is Map) {
        rawReactions.forEach((key, value) {
          if (value is List) {
            parsedReactions[key.toString()] =
                value.map((e) => e.toString()).toList();
          }
        });
      }
    }

    // Defensive parsing for booleans from DIFFERENT sources (SQLite 0/1, Supabase true/false)
    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return false;
    }

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? map['sender']?.toString() ?? '',
      receiverId:
          map['receiver_id']?.toString() ?? map['receiver']?.toString() ?? '',
      content: map['message'] ?? map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? (DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
              .toLocal()
          : DateTime.now(),
      replyTo: map['reply_to']?.toString(),
      reactions: parsedReactions,
      isForwarded: parseBool(map['is_forwarded']),
      isDeleted: parseBool(map['is_deleted']),
      updatedAt:
          DateTime.parse(map['updated_at'] ?? map['timestamp'].toString())
              .toLocal(),
      isSynced: map['is_synced'] == 1,
    );
  }

  /// Returns the timestamp specifically in Asia/Manila (PHT) for UI display
  DateTime get phtTimestamp {
    try {
      final manila = tz.getLocation('Asia/Manila');
      return tz.TZDateTime.from(timestamp, manila);
    } catch (e) {
      // Fallback to regular timestamp if timezone not initialized
      return timestamp.toLocal();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'reply_to': replyTo,
      'reactions': jsonEncode(reactions),
      'is_forwarded': isForwarded ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Map for Supabase (uses actual booleans)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender': senderId,
      'patient_id': senderId == 'admin' ? receiverId : senderId,
      'content': content,
      'message': content,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'reply_to': replyTo,
      'reactions': reactions,
      'is_forwarded': isForwarded,
      'is_deleted': isDeleted,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? content,
    Map<String, List<String>>? reactions,
    bool? isForwarded,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      content: content ?? this.content,
      timestamp: timestamp,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      isForwarded: isForwarded ?? this.isForwarded,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
