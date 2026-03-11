import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/kiosk_scaffold.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';

// DATA & REPO
import '../../../user_history/data/history_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../models/vital_signs_model.dart';

enum SensorType { temperature, bloodPressure, heartRate, oxygen }

class SingleSensorTestScreen extends StatefulWidget {
  final SensorType type;

  const SingleSensorTestScreen({super.key, required this.type});

  @override
  State<SingleSensorTestScreen> createState() => _SingleSensorTestScreenState();
}

class _SingleSensorTestScreenState extends State<SingleSensorTestScreen> {
  // 0 = Intro, 1 = Scanning (Simulated), 2 = Result
  int _viewState = 0;
  String _liveDisplay = "--";
  Timer? _simTimer;

  void _startScan() {
    setState(() => _viewState = 1);
    context.read<HealthWizardProvider>().startHealthCheck();

    // SIMULATE LIVE READING FLUCTUATION
    int ticks = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      ticks++;
      if (mounted) {
        setState(() {
          // Generate realistic fluctuations based on sensor type
          if (widget.type == SensorType.temperature) {
            _liveDisplay =
                (34.0 + Random().nextDouble() * 3).toStringAsFixed(1);
          } else if (widget.type == SensorType.heartRate) {
            _liveDisplay = (60 + Random().nextInt(40)).toString();
          } else if (widget.type == SensorType.oxygen) {
            _liveDisplay = (90 + Random().nextInt(9)).toString();
          } else if (widget.type == SensorType.bloodPressure) {
            _liveDisplay =
                "${90 + Random().nextInt(50)}"; // Just Systolic for animation
          }
        });
      }

      // Stop after 4 seconds (simulate sensor lock)
      if (ticks > 25) {
        timer.cancel();
        if (mounted) setState(() => _viewState = 2);
      }
    });
  }

  void _stopAndExit() {
    context.read<HealthWizardProvider>().stopHealthCheck();
    context.pop();
  }

  Future<void> _saveAndFinish() async {
    final provider = context.read<HealthWizardProvider>();
    final historyRepo = context.read<HistoryRepository>();
    final authRepo = context.read<AuthRepository>();

    if (authRepo.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No user logged in")));
      return;
    }

    final VitalSigns record = VitalSigns(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: authRepo.currentUser!.id,
      timestamp: DateTime.now(),
      heartRate:
          widget.type == SensorType.heartRate ? provider.currentHeartRate : 0,
      systolicBP: widget.type == SensorType.bloodPressure
          ? provider.currentSystolic
          : 0,
      diastolicBP: widget.type == SensorType.bloodPressure
          ? provider.currentDiastolic
          : 0,
      oxygen: widget.type == SensorType.oxygen ? provider.currentSpO2 : 0,
      temperature:
          widget.type == SensorType.temperature ? provider.currentTemp : 0.0,
    );

    await historyRepo.addRecord(record);
    provider.stopHealthCheck();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Result saved to History"),
        backgroundColor: AppColors.brandGreen,
        duration: Duration(seconds: 2),
      ));
      context.pop();
    }
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();

    // Config based on Type
    String title = "";
    String instruction = "";
    String info = "";
    String valueDisplay = "";
    String unit = "";
    String interpretation = "Normal";
    Color statusColor = AppColors.brandGreen;
    IconData icon = Icons.help;

    switch (widget.type) {
      case SensorType.temperature:
        title = "Body Temperature";
        instruction = "Position forehead 5cm from sensor.";
        info = "Detects fever or hypothermia.";
        valueDisplay = provider.currentTemp.toStringAsFixed(1);
        unit = "°C";
        icon = Icons.thermostat_rounded;
        if (provider.currentTemp > 37.5) {
          interpretation = "Fever";
          statusColor = Colors.orange;
        }
        break;
      case SensorType.bloodPressure:
        title = "Blood Pressure";
        instruction = "Keep arm steady at heart level.";
        info = "Measures heart workload.";
        valueDisplay =
            "${provider.currentSystolic}/${provider.currentDiastolic}";
        unit = "mmHg";
        icon = Icons.speed_rounded;
        if (provider.currentSystolic > 130) {
          interpretation = "High";
          statusColor = Colors.red;
        }
        break;
      case SensorType.heartRate:
        title = "Heart Rate";
        instruction = "Place finger on the sensor.";
        info = "Measures pulse speed.";
        valueDisplay = "${provider.currentHeartRate}";
        unit = "bpm";
        icon = Icons.favorite_rounded;
        if (provider.currentHeartRate > 100) {
          interpretation = "Fast";
          statusColor = Colors.orange;
        }
        break;
      case SensorType.oxygen:
        title = "Oxygen Saturation";
        instruction = "Keep finger still in the clip.";
        info = "Measures lung efficiency.";
        valueDisplay = "${provider.currentSpO2}";
        unit = "%";
        icon = Icons.air_rounded;
        if (provider.currentSpO2 < 95) {
          interpretation = "Low";
          statusColor = Colors.red;
        }
        break;
    }

    return KioskScaffold(
      title: title,
      onBackTap: _stopAndExit,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _viewState == 0
              ? _buildIntroView(icon, instruction, title, info, statusColor)
              : _buildScanningView(
                  icon,
                  statusColor,
                  _viewState == 2 ? valueDisplay : _liveDisplay,
                  unit,
                  interpretation),
        ),
      ),
    );
  }

  // --- VIEW 1: INTRO (Instruction First) ---
  Widget _buildIntroView(IconData icon, String instruction, String title,
      String info, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5)
            ],
          ),
          child: Icon(icon, size: 80, color: color),
        ),
        const SizedBox(height: 40),
        const Text("Ready to Measure",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDark)),
        const SizedBox(height: 16),

        // Instruction Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: color),
                  const SizedBox(width: 12),
                  const Text("INSTRUCTION",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, color: Colors.black87, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text(info,
            style: const TextStyle(
                color: Colors.grey, fontStyle: FontStyle.italic)),

        const SizedBox(height: 40),

        FlowAnimatedButton(
          child: ElevatedButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.play_arrow_rounded, size: 32),
            label: const Text("Start Measurement",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  // --- VIEW 2 & 3: SCANNING & RESULT ---
  Widget _buildScanningView(
      IconData icon, Color color, String value, String unit, String status) {
    bool isDone = _viewState == 2;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Live Circle
        Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
                color: isDone ? color : Colors.grey.shade300, width: 8),
            boxShadow: [
              BoxShadow(
                color: isDone
                    ? color.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 40,
                spreadRadius: 10,
              )
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isDone)
                  const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 4))
                else
                  Icon(icon, size: 48, color: color),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: isDone ? AppColors.brandDark : Colors.grey[400]),
                ),
                Text(
                  unit,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 48),

        // Result Interpretation Pill
        if (isDone)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          )
        else
          const Text("Analyzing...",
              style: TextStyle(
                  fontSize: 24, color: Colors.grey, letterSpacing: 2.0)),

        const SizedBox(height: 60),

        // Save Button
        if (isDone)
          FlowAnimatedButton(
            child: ElevatedButton(
              onPressed: _saveAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              child: const Text("Save & Close",
                  style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}
