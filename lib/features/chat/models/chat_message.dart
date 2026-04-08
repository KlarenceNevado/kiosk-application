import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/services/security/encryption_service.dart';

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
  final String? mediaUrl;
  final String? mediaPath;

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
    this.mediaUrl,
    this.mediaPath,
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

    // Extraction & Decryption
    String content = map['message'] ?? map['content'] ?? '';

    // Decrypt if it looks like E2EE content (contains IV separator ':')
    if (content.contains(':') && !content.startsWith('http')) {
      try {
        content = EncryptionService().decryptData(content);
      } catch (_) {
        // If decryption fails, keep original (might be a false positive or wrong key)
      }
    }

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? map['sender']?.toString() ?? '',
      receiverId:
          map['receiver_id']?.toString() ?? map['receiver']?.toString() ?? '',
      content: content,
      timestamp: map['timestamp'] != null
          ? (DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
              .toLocal()
          : DateTime.now(),
      replyTo: map['reply_to']?.toString(),
      reactions: parsedReactions,
      isForwarded: parseBool(map['is_forwarded']),
      isDeleted: parseBool(map['is_deleted']),
      updatedAt: DateTime.parse(map['updated_at'] ??
              map['timestamp']?.toString() ??
              DateTime.now().toIso8601String())
          .toLocal(),
      isSynced: map['is_synced'] == 1,
      mediaUrl: map['media_url'],
      mediaPath: map['media_path'],
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
    // Supabase alignment for local persistence
    final safeSenderId = senderId.isEmpty ? 'admin' : senderId;
    final safeReceiverId = receiverId.isEmpty ? 'system' : receiverId;
    final patientId = safeSenderId == 'admin' ? safeReceiverId : safeSenderId;

    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender': senderId,
      'patient_id': patientId,
      'content': content,
      'message': content,
      'timestamp': timestamp.toIso8601String(),
      'reply_to': replyTo,
      'reactions': jsonEncode(reactions),
      'is_forwarded': isForwarded ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
      'media_url': mediaUrl,
      'media_path': mediaPath,
    };
  }

  /// Map for Supabase (uses actual booleans and handles UUID null/empty safety)
  Map<String, dynamic> toSupabaseMap() {
    // Supabase requires valid UUIDs or non-empty strings for NOT NULL columns.
    // Ensure we don't send empty strings for these fields.
    final safeSenderId = senderId.isEmpty ? 'admin' : senderId;
    final safeReceiverId = receiverId.isEmpty ? 'system' : receiverId;

    return {
      'id': id,
      'sender_id': safeSenderId,
      'receiver_id': safeReceiverId,
      'sender': safeSenderId,
      'patient_id': safeSenderId == 'admin' ? safeReceiverId : safeSenderId,
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
