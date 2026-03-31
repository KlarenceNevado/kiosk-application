import 'dart:async';
import 'package:flutter/material.dart';
import 'power_manager_service.dart';

class SessionTimeoutManager extends StatefulWidget {

  final Widget? child;
  final Duration duration;
  final VoidCallback? onTimeout;
  final bool isPaused;

  const SessionTimeoutManager({
    super.key,
    this.child,
    this.duration = const Duration(seconds: 45),
    this.onTimeout,
    this.isPaused = false,
  });



  @override
  State<SessionTimeoutManager> createState() => _SessionTimeoutManagerState();
}

class _SessionTimeoutManagerState extends State<SessionTimeoutManager> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant SessionTimeoutManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      debugPrint("🕒 Session Timer State Changed: isPaused = ${widget.isPaused}");
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.isPaused) {
      debugPrint("🕒 Session Timer PAUSED (Kiosk Activity Active)");
      return;
    }
    _timer = Timer(widget.duration, _handleTimeout);
    debugPrint("🕒 Session Timer Started: ${widget.duration.inSeconds}s");
  }

  void _handleTimeout() {
    debugPrint("🕒 Session Timer Triggered");
    if (!mounted) return;

    // Delegate all logout/navigation logic to the parent via callback
    widget.onTimeout?.call();
  }




  void _handleInteraction([dynamic _]) {
    debugPrint("🕒 Session Timer Reset");
    PowerManagerService().notifyActivity();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleInteraction,
      child: widget.child ?? const SizedBox.shrink(),
    );
  }
}

