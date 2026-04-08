import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/notification_service.dart';
import '../security/encryption_service.dart';

class ChatListenerService {
  static final ChatListenerService _instance = ChatListenerService._internal();
  factory ChatListenerService() => _instance;
  ChatListenerService._internal();

  RealtimeChannel? _subscription;

  void startListening(String patientId, {int retryCount = 0}) {
    if (_subscription != null && retryCount == 0) return;
    _subscription?.unsubscribe();

    debugPrint(
        "📡 Starting Background Chat Listener for Patient: $patientId... (Attempt ${retryCount + 1})");

    late final RealtimeChannel channel;
    channel = Supabase.instance.client
        .channel('public:chat_notifications:$patientId');
    _subscription = channel;

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      callback: (payload) async {
        final data = payload.newRecord;

        // Dart-side filtering to avoid Supabase Realtime multiplexing bug
        if (data['receiver_id'] == patientId || data['receiver'] == patientId) {
          // Only notify if the sender is 'admin' (don't notify own messages)
          if (data['sender_id'] == 'admin' || data['sender'] == 'admin') {
            final String rawMessage =
                data['message'] ?? data['content'] ?? 'You have a new message.';

            String displayMessage = rawMessage;

            // Decrypt the message if it appears to be encrypted (contains colon marker)
            if (rawMessage.contains(':')) {
              try {
                // Ensure encryption service is initialized
                await EncryptionService().init();
                displayMessage = EncryptionService().decryptData(rawMessage);
              } catch (e) {
                debugPrint("🔐 [ChatListener] Decryption failed: $e");
                // Fallback to generic message if decryption fails for safety
                displayMessage =
                    "You have a new message from the Health Worker.";
              }
            }

            NotificationService().showChatNotification(
              senderName: 'Health Worker',
              message: displayMessage,
            );
          }
        }
      },
    )
        .subscribe((status, [error]) {
      debugPrint("📡 Chat Listener ($patientId): Status is $status");
      if (error != null) {
        debugPrint("❌ Chat Listener Error: $error");
      }

      // Supabase auto-reconnects on closed/error.
      // Do not manually retry here to prevent channel thrashing and hitting connection limits.
    });
  }

  void stopListening() {
    _subscription?.unsubscribe();
    _subscription = null;
  }
}
