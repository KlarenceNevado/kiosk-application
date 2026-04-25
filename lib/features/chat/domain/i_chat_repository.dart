import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../models/chat_message.dart';

/// Abstract interface for real-time and offline patient-to-admin chat.
abstract class IChatRepository extends ChangeNotifier {
  List<ChatMessage> get messages;
  Map<String, bool> get onlineStatus;
  User? get selectedResident;

  void setSelectedResident(User? resident);
  int getUnreadCount(String? userId);
  DateTime? getLatestMessageTime(String userId);
  void markAsRead(String otherUserId);

  void initChat(String currentUserId, String otherUserId);

  Future<void> sendMessage(ChatMessage message);

  Future<void> toggleReaction(String messageId, String userId, String emoji);

  Future<void> forwardMessage(ChatMessage original, String targetUserId);

  Future<void> deleteMessage(String messageId);
}
