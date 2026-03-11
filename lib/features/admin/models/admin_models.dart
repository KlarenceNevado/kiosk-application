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
  final Map<String, dynamic>? reactions; // { emoji: [userIds] }

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.targetGroup,
    required this.timestamp,
    required this.isActive,
    this.reactions,
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
      'targetGroup': targetGroup,
      'timestamp': timestamp.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'reactions': reactions,
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
      isActive: map['isActive'] == 1 || map['is_active'] == true,
      reactions: parsedReactions,
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
      'colorValue': color.toARGB32(),
    };
  }

  factory HealthActivity.fromMap(Map<String, dynamic> map) {
    return HealthActivity(
      id: map['id'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      location: map['location'],
      assigned: map['assigned'],
      color: Color(map['colorValue']),
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
      'targetGroup': targetGroup,
      'isEmergency': isEmergency ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory SystemAlert.fromMap(Map<String, dynamic> map) {
    return SystemAlert(
      id: map['id'],
      message: map['message'],
      targetGroup: map['targetGroup'],
      isEmergency: map['isEmergency'] == 1 || map['is_emergency'] == true,
      timestamp: DateTime.parse(map['timestamp']),
      isActive: map['isActive'] == 1 ||
          map['is_active'] == true ||
          (map['isActive'] == null &&
              map['is_active'] == null), // Default true for legacy
    );
  }
}
