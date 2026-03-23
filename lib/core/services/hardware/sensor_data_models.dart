import 'sensor_service_interface.dart';

/// Unified model for Weight Scale data
class WeightData {
  final double weight;
  final String unit;
  final DateTime timestamp;

  WeightData({
    required this.weight,
    this.unit = 'kg',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Unified model for Pulse Oximeter data
class OximeterData {
  final int spo2;
  final int bpm;
  final DateTime timestamp;

  OximeterData({
    required this.spo2,
    required this.bpm,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Unified model for IR Thermometer data
class TempData {
  final double temperature;
  final String unit;
  final DateTime timestamp;

  TempData({
    required this.temperature,
    this.unit = 'C',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Unified model for Blood Pressure data
class BPData {
  final int systolic;
  final int diastolic;
  final int pulse;
  final DateTime timestamp;

  BPData({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Generic wrapper for any sensor event
class SensorEvent<T> {
  final SensorType type;
  final T? data;
  final SensorStatus status;
  final String? error;

  SensorEvent({
    required this.type,
    this.data,
    this.status = SensorStatus.disconnected,
    this.error,
  });
}
