import 'dart:async';
import 'dart:math'; // For mock simulation
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../../../core/services/hardware/sensor_service_interface.dart';
import '../models/vital_signs_model.dart';

class HealthWizardProvider extends ChangeNotifier {
  final ISensorService _sensorService;

  // LIVE DATA STATES
  int _currentHeartRate = 0;
  int _currentSpO2 = 0;
  double _currentTemp = 0.0;
  int _currentSystolic = 0;
  int _currentDiastolic = 0;

  // BMI DATA
  int _heightCm = 165;
  double _weightKg = 70.0;

  // SYSTEM STATE
  SensorStatus _status = SensorStatus.disconnected;
  StreamSubscription? _hrSubscription;
  StreamSubscription? _statusSubscription;

  // GETTERS
  int get currentHeartRate => _currentHeartRate;
  int get currentSpO2 => _currentSpO2;
  double get currentTemp => _currentTemp;
  int get currentSystolic => _currentSystolic;
  int get currentDiastolic => _currentDiastolic;

  // BMI Getters
  int get heightCm => _heightCm;
  // FIXED: Added missing getter for weightKg
  double get weightKg => _weightKg;

  SensorStatus get status => _status;
  bool get isScanning => _status == SensorStatus.reading;
  bool get isConnecting => _status == SensorStatus.connecting;

  double get bmi {
    if (_heightCm == 0) return 0.0;
    double heightM = _heightCm / 100.0;
    return _weightKg / (heightM * heightM);
  }

  String get bmiCategory {
    double b = bmi;
    if (b <= 0) return "N/A";
    if (b < 18.5) return "Underweight";
    if (b < 25) return "Normal";
    if (b < 30) return "Overweight";
    return "Obese";
  }

  HealthWizardProvider(this._sensorService);

  // --- ACTIONS ---

  void setHeight(int height) {
    _heightCm = height;
    notifyListeners();
  }

  // Simulate weight reading
  void setWeight(double weight) {
    _weightKg = weight;
    notifyListeners();
  }

  void startHealthCheck() {
    _statusSubscription?.cancel();
    _statusSubscription = _sensorService.statusStream.listen((newStatus) {
      _status = newStatus;
      notifyListeners();
    });

    _hrSubscription?.cancel();
    _hrSubscription = _sensorService.heartRateStream.listen((data) {
      _currentHeartRate = data;

      // MOCK: Generate other vitals based on heart rate
      final random = Random();
      _currentSpO2 = 96 + random.nextInt(4); // 96-99
      _currentTemp = 36.5 + (random.nextDouble() * 1.0); // 36.5 - 37.5
      _currentSystolic = 110 + random.nextInt(20); // 110-130
      _currentDiastolic = 70 + random.nextInt(15); // 70-85

      if (_weightKg > 0) {
        _weightKg = 70.0 + (random.nextDouble() * 0.2);
      }

      notifyListeners();
    });

    _sensorService.startReading();
  }

  void stopHealthCheck() {
    _sensorService.stopReading();
    _hrSubscription?.cancel();
    _statusSubscription?.cancel();

    _status = SensorStatus.disconnected;
    notifyListeners();
  }

  // Generate Final Data for Saving
  // FIXED: Ensure userId is required
  VitalSigns generateFinalResult(String userId) {
    return VitalSigns(
      id: const Uuid().v4(),
      userId: userId,
      timestamp: DateTime.now(),
      heartRate: _currentHeartRate == 0 ? 75 : _currentHeartRate,
      systolicBP: _currentSystolic == 0 ? 120 : _currentSystolic,
      diastolicBP: _currentDiastolic == 0 ? 80 : _currentDiastolic,
      oxygen: _currentSpO2 == 0 ? 98 : _currentSpO2,
      temperature: _currentTemp == 0
          ? 36.6
          : double.parse(_currentTemp.toStringAsFixed(1)),
      bmi: bmi,
      bmiCategory: bmiCategory,
    );
  }

  @override
  void dispose() {
    _hrSubscription?.cancel();
    _statusSubscription?.cancel();
    _sensorService.stopReading();
    super.dispose();
  }
}
