import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database/connection_manager.dart';
import '../services/database/sync_service.dart';
import 'package:intl/intl.dart';

class SyncStatusIndicator extends StatefulWidget {
  final bool showLabel;
  final Color? color;

  const SyncStatusIndicator({
    super.key,
    this.showLabel = true,
    this.color,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh the "time ago" label every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return "Never synced";
    final diff = DateTime.now().difference(lastSync);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return DateFormat('HH:mm').format(lastSync);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectionManager(),
      builder: (context, _) {
        final isOnline = ConnectionManager().isOnline;
        final statusColor = isOnline ? Colors.greenAccent : Colors.orangeAccent;

        return StreamBuilder<DateTime?>(
          stream: SyncService().lastSyncStream,
          initialData: SyncService().lastSyncTime,
          builder: (context, snapshot) {
            final lastSync = snapshot.data;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (widget.color ?? Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (widget.color ?? Colors.black).withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: isOnline ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (isOnline)
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.showLabel) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatLastSync(lastSync),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: (widget.color ?? Colors.black).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
