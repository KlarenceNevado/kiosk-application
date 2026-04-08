import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class Announcement {
  final String id;
  final String title;
  final String content;
  final String targetGroup;
  final DateTime timestamp;
  final bool isActive;
  final bool isArchived;
  final Map<String, dynamic>? reactions; // { emoji: [userIds] }
  final String? mediaUrl;
  final String? mediaPath;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.targetGroup,
    required this.timestamp,
    required this.isActive,
    this.isArchived = false,
    this.reactions,
    this.mediaUrl,
    this.mediaPath,
  });

  /// Returns the timestamp specifically in Asia/Manila (PHT) for UI display
  DateTime get phtTimestamp {
    try {
      final manila = tz.getLocation('Asia/Manila');
      return tz.TZDateTime.from(timestamp, manila);
    } catch (e) {
      return timestamp.toLocal();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'target_group': targetGroup,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'reactions': reactions,
      'media_url': mediaUrl,
      'media_path': mediaPath,
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    dynamic rawReactions = map['reactions'];
    Map<String, dynamic>? parsedReactions;

    if (rawReactions is String) {
      try {
        parsedReactions = Map<String, dynamic>.from(json.decode(rawReactions));
      } catch (e) {
        debugPrint("❌ Announcement.fromMap: Failed to decode reactions: $e");
      }
    } else if (rawReactions is Map) {
      parsedReactions = Map<String, dynamic>.from(rawReactions);
    }

    return Announcement(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      targetGroup: map['targetGroup'] ?? map['target_group'] ?? 'all',
      timestamp: DateTime.parse(map['timestamp']),
      isActive: map['is_active'] == 1 ||
          map['is_active'] == true ||
          map['isActive'] == 1 ||
          map['isActive'] == true,
      isArchived: map['is_archived'] == 1 ||
          map['is_archived'] == true ||
          map['isArchived'] == 1 ||
          map['isArchived'] == true,
      reactions: parsedReactions,
      mediaUrl: map['media_url'],
      mediaPath: map['media_path'],
    );
  }
}

class HealthActivity {
  final String id;
  final String type;
  final DateTime date;
  final String location;
  final String assigned;
  final Color color;

  HealthActivity({
    required this.id,
    required this.type,
    required this.date,
    required this.location,
    required this.assigned,
    required this.color,
  });

  /// Returns the date specifically in Asia/Manila (PHT) for UI display
  DateTime get phtDate {
    try {
      final manila = tz.getLocation('Asia/Manila');
      return tz.TZDateTime.from(date, manila);
    } catch (e) {
      return date.toLocal();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'date': date.toIso8601String(),
      'location': location,
      'assigned': assigned,
      'color_value': color.toARGB32(),
    };
  }

  factory HealthActivity.fromMap(Map<String, dynamic> map) {
    return HealthActivity(
      id: map['id'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      location: map['location'],
      assigned: map['assigned'],
      color: Color(map['color_value'] ?? map['colorValue']),
    );
  }
}

class SystemAlert {
  final String id;
  final String message;
  final String targetGroup;
  final bool isEmergency;
  final DateTime timestamp;
  final bool isActive;

  SystemAlert({
    required this.id,
    required this.message,
    required this.targetGroup,
    required this.isEmergency,
    required this.timestamp,
    required this.isActive,
  });

  /// Returns the timestamp specifically in Asia/Manila (PHT) for UI display
  DateTime get phtTimestamp {
    try {
      final manila = tz.getLocation('Asia/Manila');
      return tz.TZDateTime.from(timestamp, manila);
    } catch (e) {
      return timestamp.toLocal();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'target_group': targetGroup,
      'is_emergency': isEmergency ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory SystemAlert.fromMap(Map<String, dynamic> map) {
    return SystemAlert(
      id: map['id'],
      message: map['message'],
      targetGroup: map['target_group'] ?? map['targetGroup'] ?? 'all',
      isEmergency: map['is_emergency'] == 1 ||
          map['is_emergency'] == true ||
          map['isEmergency'] == 1 ||
          map['isEmergency'] == true,
      timestamp: DateTime.parse(map['timestamp']),
      isActive: map['is_active'] == 1 ||
          map['is_active'] == true ||
          map['isActive'] == 1 ||
          map['isActive'] == true ||
          (map['isActive'] == null && map['is_active'] == null),
    );
  }
}
