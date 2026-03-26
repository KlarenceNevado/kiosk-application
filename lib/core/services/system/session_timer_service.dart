import 'dart:async';
import 'package:flutter/material.dart';

class SessionTimeoutManager extends StatefulWidget {

  final Widget? child;
  final Duration duration;
  final VoidCallback? onTimeout;

  const SessionTimeoutManager({
    super.key,
    this.child,
    this.duration = const Duration(seconds: 45),
    this.onTimeout,
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
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

