import 'package:flutter/material.dart';
import 'package:kiosk_application/core/services/system/initialization_service.dart';
import 'package:kiosk_application/core/widgets/logo_glow.dart';

/// The Zero-Latency Startup Gateway.
/// This widget renders immediately (no white screen) and manages
/// the two-tier initialization process in the background.
class StartupGateway extends StatefulWidget {
  final Widget Function(BuildContext) builder;

  const StartupGateway({
    super.key,
    required this.builder,
  });

  @override
  State<StartupGateway> createState() => _StartupGatewayState();
}

class _StartupGatewayState extends State<StartupGateway> {
  bool _isCriticalReady = false;
  String _status = "Starting System...";

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    try {
      // 1. Tier 1: Critical Local Setup (Fast)
      // This happens while the user sees the LogoGlow.
      await InitializationService().initializeCritical();

      if (mounted) {
        setState(() {
          _isCriticalReady = true;
          _status = "Syncing Cloud...";
        });
      }

      // 2. Tier 2: Deferred Setup (Network/Hardware)
      // We don't await this to keep the "Flip" to the Login screen instant.
      InitializationService().initializeDeferred();
    } catch (e) {
      if (mounted) {
        setState(() => _status = "System Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If critical setup is done, render the main application (MultiProvider + Router)
    if (_isCriticalReady) {
      return widget.builder(context);
    }

    // Otherwise, show the branded Startup Screen immediately
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LogoGlow(size: 180),
              const SizedBox(height: 32),
              Text(
                _status,
                style: const TextStyle(
                  color: Color(0xFF8CC63F),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8CC63F)),
                  minHeight: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
