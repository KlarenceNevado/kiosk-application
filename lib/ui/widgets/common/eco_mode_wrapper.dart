import 'package:flutter/material.dart';
import '../../../core/services/system/app_environment.dart';

/// A wrapper widget that suspends all animations (Tickers) system-wide
/// when PowerManagerService enters Eco-Mode.
class EcoModeWrapper extends StatelessWidget {
  final Widget child;
  final _env = AppEnvironment();

  EcoModeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _env.isEcoModeActive,
      builder: (context, isEcoActive, child) {
        return TickerMode(
          enabled: !isEcoActive, // Disabling tickers stops all animations
          child: Stack(
            children: [
              child!,
              if (isEcoActive) _buildEcoOverlay(),
            ],
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildEcoOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text(
                'Solar Eco-Mode Active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Touch anywhere to wake',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
