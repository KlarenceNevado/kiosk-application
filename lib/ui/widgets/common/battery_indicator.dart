import 'package:flutter/material.dart';
import '../../../core/services/system/app_environment.dart';

/// A sleek battery indicator that reflects the solar charge level 
/// monitored by the ESP32.
class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final env = AppEnvironment();

    return ValueListenableBuilder<double>(
      valueListenable: env.batteryLevel,
      builder: (context, level, child) {
        final percentage = (level * 100).toInt();
        final color = _getBatteryColor(level);
        final icon = _getBatteryIcon(level);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getBatteryColor(double level) {
    if (level > 0.6) return Colors.greenAccent;
    if (level > 0.2) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  IconData _getBatteryIcon(double level) {
    if (level > 0.9) return Icons.battery_full;
    if (level > 0.7) return Icons.battery_6_bar;
    if (level > 0.5) return Icons.battery_4_bar;
    if (level > 0.3) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }
}
