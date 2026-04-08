import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/system/sync_event_bus.dart';
import '../data/mobile_navigation_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';

class AnnouncementNotificationListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const AnnouncementNotificationListener({
    super.key,
    required this.child,
    required this.messengerKey,
  });

  @override
  State<AnnouncementNotificationListener> createState() =>
      _AnnouncementNotificationListenerState();
}

class _AnnouncementNotificationListenerState
    extends State<AnnouncementNotificationListener> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        SyncEventBus.instance.newAnnouncementStream.listen((announcement) {
      final isActive = announcement['is_active'] == 1 ||
          announcement['is_active'] == true ||
          announcement['isActive'] == 1 ||
          announcement['isActive'] == true;
      final isArchived = announcement['is_archived'] == 1 ||
          announcement['is_archived'] == true ||
          announcement['isArchived'] == 1 ||
          announcement['isArchived'] == true;
      final isDeleted =
          announcement['is_deleted'] == 1 || announcement['is_deleted'] == true;

      // Only show notification if it's active, not archived, and not deleted
      if (isActive && !isArchived && !isDeleted) {
        _showNotification(announcement);
      }
    });
  }

  void _showNotification(Map<String, dynamic> announcement) {
    final title = announcement['title'] ?? 'New Announcement';
    final targetGroup = announcement['target_group'] ?? 'all';
    final isUrgent = targetGroup == 'BROADCAST_ALL';

    widget.messengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUrgent ? Colors.red.shade800 : AppColors.brandGreen,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isUrgent ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrgent ? "URGENT BROADCAST" : "NEW ANNOUNCEMENT",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  widget.messengerKey.currentState?.hideCurrentSnackBar();
                  context.read<MobileNavigationProvider>().goToAnnouncements();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("VIEW",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
