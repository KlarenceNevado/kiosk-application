import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/kiosk_scaffold.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart' as hw;
import '../../../../core/services/system/app_environment.dart';

// DATA & REPO
import '../../../user_history/domain/i_history_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../models/vital_signs_model.dart';

enum TestSensorType { temperature, bloodPressure, heartRate, oxygen }

class SingleSensorTestScreen extends StatefulWidget {
  final TestSensorType type;

  const SingleSensorTestScreen({super.key, required this.type});

  @override
  State<SingleSensorTestScreen> createState() => _SingleSensorTestScreenState();
}

class _SingleSensorTestScreenState extends State<SingleSensorTestScreen> with TickerProviderStateMixin {
  int _viewState = 0; // 0=Prep, 1=Scanning, 2=Result, 3=Error
  String _lockedResult = ""; 
  Timer? _simTimer;
  Timer? _timeoutTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
       context.read<HealthWizardProvider>().startHealthCheck();
    });
  }

  void _startScan() {
    setState(() => _viewState = 1);
    final provider = context.read<HealthWizardProvider>();
    
    // HARDENING: Safety Timeout
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(seconds: widget.type == TestSensorType.bloodPressure ? 45 : 15), () {
      if (mounted && _viewState == 1) {
        setState(() => _viewState = 3);
      }
    });

    switch (widget.type) {
      case TestSensorType.temperature: provider.startSensor(hw.SensorType.thermometer); break;
      case TestSensorType.bloodPressure: provider.startSensor(hw.SensorType.bloodPressure); break;
      case TestSensorType.heartRate:
      case TestSensorType.oxygen: provider.startSensor(hw.SensorType.oximeter); break;
    }

    if (!AppEnvironment().useSimulation) return;

    // SIMULATION
    int ticks = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      ticks++;
      if (!mounted) { timer.cancel(); return; }
      
      if (widget.type == TestSensorType.temperature) {
        provider.setTemperature(36.1 + Random().nextDouble() * 0.5);
      } else if (widget.type == TestSensorType.heartRate || widget.type == TestSensorType.oxygen) {
        provider.setPulseOx(72 + Random().nextInt(10), 97 + Random().nextInt(3));
      } else if (widget.type == TestSensorType.bloodPressure) {
        if (ticks >= 20) provider.setBloodPressure(120 + Random().nextInt(10), 80 + Random().nextInt(5));
      }

      if (ticks >= 25) {
        timer.cancel();
      }
    });
  }

  void _lockValueAndFinish() {
    if (!mounted || _viewState == 2) return;
    _timeoutTimer?.cancel();
    final provider = context.read<HealthWizardProvider>();
    
    setState(() {
      _viewState = 2;
      switch (widget.type) {
        case TestSensorType.temperature: _lockedResult = provider.currentTemp.toStringAsFixed(1); break;
        case TestSensorType.heartRate: _lockedResult = "${provider.currentHeartRate}"; break;
        case TestSensorType.oxygen: _lockedResult = "${provider.currentSpO2}"; break;
        case TestSensorType.bloodPressure: _lockedResult = "${provider.currentSystolic}/${provider.currentDiastolic}"; break;
      }
    });
  }

  void _stopAndExit() {
    _timeoutTimer?.cancel();
    context.read<HealthWizardProvider>().stopHealthCheck();
    context.pop();
  }

  Future<void> _saveAndFinish() async {
    final provider = context.read<HealthWizardProvider>();
    final historyRepo = context.read<IHistoryRepository>();
    final authRepo = context.read<IAuthRepository>();

    if (authRepo.currentUser == null) return;

    final VitalSigns record = VitalSigns(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: authRepo.currentUser!.id,
      timestamp: DateTime.now(),
      heartRate: widget.type == TestSensorType.heartRate ? provider.currentHeartRate : 0,
      systolicBP: widget.type == TestSensorType.bloodPressure ? provider.currentSystolic : 0,
      diastolicBP: widget.type == TestSensorType.bloodPressure ? provider.currentDiastolic : 0,
      oxygen: widget.type == TestSensorType.oxygen ? provider.currentSpO2 : 0,
      temperature: widget.type == TestSensorType.temperature ? provider.currentTemp : 0.0,
    );

    await historyRepo.addRecord(record);
    provider.stopHealthCheck();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    final Color testColor = _getColor();
    final IconData icon = _getIcon();

    // HARDENING: Auto-lock logic
    if (_viewState == 1) {
      bool shouldFinish = false;
      switch (widget.type) {
        case TestSensorType.temperature: shouldFinish = provider.isVitalStable(hw.SensorType.thermometer) && provider.currentTemp > 34; break;
        case TestSensorType.heartRate: 
        case TestSensorType.oxygen: shouldFinish = provider.isVitalStable(hw.SensorType.oximeter) && provider.currentHeartRate > 40; break;
        case TestSensorType.bloodPressure: shouldFinish = provider.currentSystolic > 30; break;
      }
      if (shouldFinish) Future.delayed(Duration.zero, _lockValueAndFinish);
    }

    String displayValue = _lockedResult;
    if (_viewState == 1) {
      switch (widget.type) {
        case TestSensorType.temperature: displayValue = provider.currentTemp > 0 ? provider.currentTemp.toStringAsFixed(1) : "READING"; break;
        case TestSensorType.heartRate: displayValue = provider.currentHeartRate > 0 ? "${provider.currentHeartRate}" : "READING"; break;
        case TestSensorType.oxygen: displayValue = provider.currentSpO2 > 0 ? "${provider.currentSpO2}" : "READING"; break;
        case TestSensorType.bloodPressure: displayValue = provider.currentSystolic > 0 ? "${provider.currentSystolic}/${provider.currentDiastolic}" : "INFLATING"; break;
      }
    }

    return KioskScaffold(
      title: _getTitle(),
      onBackTap: _stopAndExit,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white, testColor.withValues(alpha: 0.02)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _viewState == 0 
                  ? _buildPrepView(testColor, icon) 
                  : _viewState == 3 ? _buildErrorView(testColor) : _buildMeasurementView(testColor, icon, displayValue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrepView(Color color, IconData icon) {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 15)],
          ),
          child: Icon(icon, size: 64, color: color),
        ),
        const SizedBox(height: 24),
        const Text("Precautionary Stage", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.08)),
          ),
          child: Text(_getInstruction(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.4)),
        ),
        const SizedBox(height: 40),
        FlowAnimatedButton(
          child: ElevatedButton(
            onPressed: _startScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 4,
            ),
            child: const Text("Start Measurement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementView(Color color, IconData icon, String value) {
    bool isDone = _viewState == 2;
    String unit = _getUnit();

    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (!isDone)
              ...List.generate(2, (index) => TweenAnimationBuilder(
                duration: Duration(seconds: 1 + index),
                tween: Tween<double>(begin: 1, end: 1.3),
                builder: (context, val, child) => Container(
                  width: 250 * val, height: 250 * val,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.15 / val), width: 2)),
                ),
              )),
            
            SizedBox(
              width: 260, height: 260,
              child: CircularProgressIndicator(
                value: isDone ? 1 : null, strokeWidth: 10, strokeCap: StrokeCap.round,
                color: isDone ? AppColors.brandGreen : color, backgroundColor: color.withValues(alpha: 0.1),
              ),
            ),

            Container(
              width: 190, height: 190,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.4)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.type == TestSensorType.heartRate && !isDone)
                    ScaleTransition(
                       scale: Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                       child: Icon(icon, color: color, size: 28),
                    )
                  else
                    Icon(icon, color: isDone ? AppColors.brandGreen : color, size: 28),
                  
                  const SizedBox(height: 6),
                  Text(value, style: TextStyle(fontSize: value.length > 5 ? 32 : 52, fontWeight: FontWeight.w900, color: isDone ? AppColors.brandGreen : color, letterSpacing: -1)),
                  Text(unit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: isDone ? AppColors.brandGreen.withValues(alpha: 0.05) : color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(50)),
          child: Text(isDone ? "TEST COMPLETE" : "STABILIZING...", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDone ? AppColors.brandGreen : color)),
        ),
        
        const SizedBox(height: 48),
        if (isDone)
          FlowAnimatedButton(
            child: ElevatedButton(
              onPressed: _saveAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 4,
              ),
              child: const Text("Save & Record Result", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(Color color) {
    return Column(
      key: const ValueKey(3),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 80),
        const SizedBox(height: 24),
        const Text("Measurement Failed", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        const SizedBox(height: 12),
        const Text("The sensor timed out. Please try again.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => setState(() => _viewState = 0),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
          child: const Text("Retry Measurement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Color _getColor() {
    switch (widget.type) {
      case TestSensorType.temperature: return Colors.orange;
      case TestSensorType.bloodPressure: return Colors.blue;
      case TestSensorType.heartRate: return Colors.red;
      case TestSensorType.oxygen: return Colors.cyan;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case TestSensorType.temperature: return Icons.thermostat_outlined;
      case TestSensorType.bloodPressure: return Icons.speed_rounded;
      case TestSensorType.heartRate: return Icons.monitor_heart_rounded;
      case TestSensorType.oxygen: return Icons.air_rounded;
    }
  }

  String _getTitle() {
     switch (widget.type) {
      case TestSensorType.temperature: return "Temperature";
      case TestSensorType.bloodPressure: return "Blood Pressure";
      case TestSensorType.heartRate: return "Heart Rate";
      case TestSensorType.oxygen: return "Oxygen";
    }
  }

  String _getInstruction() {
     switch (widget.type) {
      case TestSensorType.temperature: return "Forehead 5cm from the sensor. Remove hair/hats.";
      case TestSensorType.bloodPressure: return "Cuff on left arm, sit straight, and stay still.";
      case TestSensorType.heartRate: return "Insert index finger into the pulse clip.";
      case TestSensorType.oxygen: return "Insert index finger into the pulse clip.";
    }
  }

  String _getUnit() {
     switch (widget.type) {
      case TestSensorType.temperature: return "°C";
      case TestSensorType.bloodPressure: return "mmHg";
      case TestSensorType.heartRate: return "BPM";
      case TestSensorType.oxygen: return "% SpO2";
    }
  }
}
