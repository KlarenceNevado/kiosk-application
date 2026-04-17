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
  // Updated status tracking
  SensorStatus _status = SensorStatus.disconnected;
  final Map<SensorType, SensorStatus> _sensorStatuses = {};
  StreamSubscription? _sensorSubscription;

  // HARDENING: Stability & Heartbeat
  final Map<SensorType, List<double>> _stabilityBuffers = {};
  final Map<SensorType, DateTime> _lastHeartbeat = {};
  final Map<SensorType, bool> _sensorIsStable = {};
  final int _bufferSize = 5;

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
  double get weightKg => _weightKg;
  int get heightCm => _heightCm;

  SensorStatus get status => _status;
  bool get isScanning => _status == SensorStatus.reading;
  bool get isConnecting => _status == SensorStatus.connecting;

  SensorStatus getSensorStatus(SensorType type) =>
      _sensorStatuses[type] ?? SensorStatus.disconnected;

  bool isVitalLocked(SensorType type) {
    switch (type) {
      case SensorType.weight:
        return _isWeightLocked;
      case SensorType.thermometer:
        return _isTempLocked;
      case SensorType.oximeter:
        return _isPulseOxLocked;
      case SensorType.bloodPressure:
        return _isBpLocked;
      case SensorType.battery:
      case SensorType.height:
        return false;
    }
  }

  bool isVitalStable(SensorType type) => _sensorIsStable[type] ?? false;

  /// Returns true if the sensor hasn't sent data in the last 3.5 seconds
  bool isSensorSilent(SensorType type) {
    if (getSensorStatus(type) == SensorStatus.disconnected ||
        getSensorStatus(type) == SensorStatus.error) {
      return true;
    }
    final last = _lastHeartbeat[type];
    if (last == null) return true;
    return DateTime.now().difference(last).inMilliseconds > 3500;
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

  HealthWizardProvider(this._sensorManager) {
    // Proactive background listening for all sensors
    _sensorSubscription = _sensorManager.allDataStream.listen((event) {
      _sensorStatuses[event.type] = event.status;
      if (event.status == SensorStatus.reading) {
        _status = SensorStatus.reading;
      }

      if (event.data != null) {
        _lastHeartbeat[event.type] = DateTime.now();
        switch (event.type) {
          case SensorType.weight:
            if (!_isWeightLocked) {
              _weightKg = (event.data as num).toDouble();
              _updateStability(SensorType.weight, _weightKg);
            }
            break;
          case SensorType.oximeter:
            if (!_isPulseOxLocked) {
              final oximeter = event.data as Map<String, dynamic>;
              _currentSpO2 = oximeter['spo2'] as int;
              _currentHeartRate = oximeter['bpm'] as int;
              _updateStability(SensorType.oximeter, _currentSpO2.toDouble());
            }
            break;
          case SensorType.thermometer:
            if (!_isTempLocked) {
              _currentTemp = (event.data as num).toDouble();
              _updateStability(SensorType.thermometer, _currentTemp);
            }
            break;
          case SensorType.bloodPressure:
            if (!_isBpLocked) {
              final bp = event.data as Map<String, dynamic>;
              _currentSystolic = bp['sys'] as int;
              _currentDiastolic = bp['dia'] as int;
              _updateStability(
                  SensorType.bloodPressure, _currentSystolic.toDouble());
            }
            break;
          case SensorType.battery:
            break;
          case SensorType.height:
            _heightCm = (event.data as num).toInt();
            break;
        }
      }
      notifyListeners();
    });
  }

  void setHeight(int height) {
    _heightCm = height;
    notifyListeners();
  }

  void setTemperature(double temp) {
    _currentTemp = temp;
    _updateStability(SensorType.thermometer, temp);
    notifyListeners();
  }

  void setBloodPressure(int sys, int dia) {
    _currentSystolic = sys;
    _currentDiastolic = dia;
    _updateStability(SensorType.bloodPressure, sys.toDouble());
    notifyListeners();
  }

  void setPulseOx(int hr, int spo2) {
    _currentHeartRate = hr;
    _currentSpO2 = spo2;
    _updateStability(SensorType.oximeter, spo2.toDouble());
    notifyListeners();
  }

  void setWeight(double weight) {
    _weightKg = weight;
    _updateStability(SensorType.weight, weight);
    notifyListeners();
  }

  void _updateStability(SensorType type, double value) {
    _lastHeartbeat[type] = DateTime.now();

    _stabilityBuffers.putIfAbsent(type, () => []);
    final buffer = _stabilityBuffers[type]!;

    buffer.add(value);
    if (buffer.length > _bufferSize) buffer.removeAt(0);

    if (buffer.length == _bufferSize) {
      double min = buffer.reduce((a, b) => a < b ? a : b);
      double max = buffer.reduce((a, b) => a > b ? a : b);
      double diff = max - min;

      double tolerance =
          (type == SensorType.weight || type == SensorType.thermometer)
              ? 0.2
              : 1.5;

      bool wasStable = _sensorIsStable[type] ?? false;
      _sensorIsStable[type] = diff <= tolerance;

      if (_sensorIsStable[type]! && !wasStable) {
        debugPrint("🟢 [HealthWizardProvider] Sensor $type is now STABLE.");
      }
    }
  }

  void startHealthCheck() {
    _isSessionActive = true;
    _sensorIsStable.clear();
    _stabilityBuffers.clear();
    _isWeightLocked = false;
    _isTempLocked = false;
    _isPulseOxLocked = false;
    _isBpLocked = false;
    notifyListeners();
    SystemLogService()
        .logAction(action: 'HEALTH_CHECK_START', module: 'HEALTH_CHECK');
  }

  void captureVital(SensorType type) {
    debugPrint("📥 [HealthWizardProvider] Capturing Final $type Reading...");

    switch (type) {
      case SensorType.weight:
        _isWeightLocked = true;
        break;
      case SensorType.thermometer:
        _isTempLocked = true;
        break;
      case SensorType.oximeter:
        _isPulseOxLocked = true;
        break;
      case SensorType.bloodPressure:
        _isBpLocked = true;
        break;
      case SensorType.battery:
      case SensorType.height:
        break;
    }

    _sensorManager.stopSensor(type);

    SystemLogService().logAction(
      action: 'VITAL_CAPTURE_LOCKED',
      module: 'HEALTH_CHECK',
      userId: 'N/A',
      sensorFailures: 'Reading locked for $type',
    );

    notifyListeners();
  }

  void stopHealthCheck() {
    _isSessionActive = false;
    SystemLogService()
        .logAction(action: 'HEALTH_CHECK_STOP', module: 'HEALTH_CHECK');
    _sensorManager.stopAll();
    _status = SensorStatus.disconnected;
    _sensorIsStable.clear();
    _stabilityBuffers.clear();
    notifyListeners();
  }

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
      heartRate: _currentHeartRate,
      systolicBP: _currentSystolic,
      diastolicBP: _currentDiastolic,
      oxygen: _currentSpO2,
      temperature: _currentTemp == 0
          ? 0.0
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
