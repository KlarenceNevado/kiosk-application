import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../../../core/services/hardware/sensor_service_interface.dart';
import '../../../core/services/hardware/sensor_manager.dart';
import '../models/vital_signs_model.dart';
import '../../../core/services/system/system_log_service.dart';

class HealthWizardProvider extends ChangeNotifier {
  final SensorManager _sensorManager;

  // LIVE DATA STATES
  int _currentHeartRate = 0;
  int _currentSpO2 = 0;
  double _currentTemp = 0.0;
  int _currentSystolic = 0;
  int _currentDiastolic = 0;

  // BMI DATA
  int _heightCm = 165;
  double _weightKg = 70.0;

  bool _isSessionActive = false;
  SensorStatus _status = SensorStatus.disconnected;
  StreamSubscription? _sensorSubscription;

  bool get isSessionActive => _isSessionActive;

  // LOCK STATES (To prevent fluctuation after capture)
  bool _isWeightLocked = false;
  bool _isTempLocked = false;
  bool _isPulseOxLocked = false;
  bool _isBpLocked = false;

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

  bool isVitalLocked(SensorType type) {
    switch (type) {
      case SensorType.weight: return _isWeightLocked;
      case SensorType.thermometer: return _isTempLocked;
      case SensorType.oximeter: return _isPulseOxLocked;
      case SensorType.bloodPressure: return _isBpLocked;
      case SensorType.battery: return false;
    }
  }

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

  HealthWizardProvider(this._sensorManager);

  // --- ACTIONS ---

  void setHeight(int height) {
    _heightCm = height;
    notifyListeners();
  }

  // Simulation / Manual Setters
  void setTemperature(double temp) {
    _currentTemp = temp;
    notifyListeners();
  }

  void setBloodPressure(int sys, int dia) {
    _currentSystolic = sys;
    _currentDiastolic = dia;
    notifyListeners();
  }

  void setPulseOx(int hr, int spo2) {
    _currentHeartRate = hr;
    _currentSpO2 = spo2;
    notifyListeners();
  }

  void setWeight(double weight) {
    _weightKg = weight;
    notifyListeners();
  }

  void startHealthCheck() {
    _isSessionActive = true;
    notifyListeners();
    SystemLogService().logAction(action: 'HEALTH_CHECK_START', module: 'HEALTH_CHECK');

    _sensorSubscription?.cancel();
    _sensorSubscription = _sensorManager.allDataStream.listen((event) {
      _status = event.status;

      if (event.data != null) {
        switch (event.type) {
          case SensorType.weight:
            if (!_isWeightLocked) _weightKg = event.data as double;
            break;
          case SensorType.oximeter:
            if (!_isPulseOxLocked) {
              final oximeter = event.data as Map<String, dynamic>;
              _currentSpO2 = oximeter['spo2'] as int;
              _currentHeartRate = oximeter['bpm'] as int;
            }
            break;
          case SensorType.thermometer:
            if (!_isTempLocked) _currentTemp = event.data as double;
            break;
          case SensorType.bloodPressure:
            if (!_isBpLocked) {
              final bp = event.data as Map<String, dynamic>;
              _currentSystolic = bp['sys'] as int;
              _currentDiastolic = bp['dia'] as int;
            }
            break;
          case SensorType.battery:
            // Handled by PowerManager, not used in Wizard UI
            break;
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint("❌ HealthWizardProvider: Sensor Error Observed: $e");
      _status = SensorStatus.error;
      notifyListeners();
    });
  }

  /// Captures the current vital reading, locks it, and stops the sensor.
  void captureVital(SensorType type) {
    debugPrint("📥 [HealthWizardProvider] Capturing Final $type Reading...");
    
    switch (type) {
      case SensorType.weight: _isWeightLocked = true; break;
      case SensorType.thermometer: _isTempLocked = true; break;
      case SensorType.oximeter: _isPulseOxLocked = true; break;
      case SensorType.bloodPressure: _isBpLocked = true; break;
      case SensorType.battery: break;
    }

    _sensorManager.stopSensor(type);
    
    SystemLogService().logAction(
      action: 'VITAL_CAPTURE_LOCKED',
      module: 'HEALTH_CHECK',
      sensorFailures: 'Reading locked for $type',
    );
    
    notifyListeners();
  }



  void stopHealthCheck() {
    _isSessionActive = false;
    SystemLogService().logAction(action: 'HEALTH_CHECK_STOP', module: 'HEALTH_CHECK');
    _sensorManager.stopAll();
    _sensorSubscription?.cancel();

    _status = SensorStatus.disconnected;
    notifyListeners();
  }

  // Generate Final Data for Saving
  // FIXED: Ensure userId is required
  VitalSigns generateFinalResult(String userId) {
    SystemLogService().logAction(
      action: 'VITAL_SIGNS_CAPTURED',
      module: 'HEALTH_CHECK',
      userId: userId,
    );
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

  void startSensor(SensorType type) {
    _sensorManager.startSensor(type);
  }

  void stopSensor(SensorType type) {
    _sensorManager.stopSensor(type);
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _sensorManager.stopAll();
    super.dispose();
  }
}

