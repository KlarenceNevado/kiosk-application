import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// FIXED: Correct relative path to routes
import '../../config/routes.dart';

class SessionTimeoutManager extends StatefulWidget {
  final Widget? child;
  final Duration duration;

  const SessionTimeoutManager(
      {super.key, this.child, this.duration = const Duration(minutes: 2)});

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
  }

  void _handleTimeout() {
    if (!mounted) return;

    // Check current route to avoid redirecting if already at login
    // This requires GoRouter to be available in the context
    try {
      final router = GoRouter.of(context);
      final String location =
          router.routerDelegate.currentConfiguration.uri.toString();

      if (location != AppRoutes.login) {
        debugPrint("⚠️ Session Timeout");
        router.go(AppRoutes.login);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Session timed out due to inactivity."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Router might not be ready
    }
  }

  void _handleInteraction([dynamic _]) => _startTimer();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleInteraction,
      onPointerMove: _handleInteraction,
      onPointerHover: _handleInteraction,
      onPointerUp: _handleInteraction,
      child: widget.child ?? const SizedBox.shrink(),
    );
  }
}
