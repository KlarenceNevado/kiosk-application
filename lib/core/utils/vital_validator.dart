import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum HealthStatus { normal, warning, critical, low, error }

class VitalEvaluation {
  final HealthStatus status;
  final String label;
  final Color color;
  final String advice;

  VitalEvaluation(this.status, this.label, this.color, this.advice);
}

class VitalValidator {
  // Private constructor
  VitalValidator._();

  // --- BLOOD PRESSURE (JNC 7 Guidelines) ---
  static VitalEvaluation evaluateBP(int sys, int dia) {
    if (sys == 0 || dia == 0) return _error();

    if (sys < 90 || dia < 60) {
      return VitalEvaluation(
          HealthStatus.low,
          "Low (Hypotension)",
          Colors.orange,
          "Drink water and eat a salty snack. Sit down if dizzy.");
    }
    if (sys < 120 && dia < 80) {
      return VitalEvaluation(HealthStatus.normal, "Normal",
          AppColors.brandGreen, "Great job! Maintain a healthy lifestyle.");
    }
    if (sys < 130 && dia < 80) {
      return VitalEvaluation(HealthStatus.warning, "Elevated",
          Colors.yellow[800]!, "Monitor daily. Reduce sodium intake.");
    }
    if (sys < 140 || dia < 90) {
      return VitalEvaluation(HealthStatus.warning, "High (Stage 1)",
          Colors.orange, "Consult a doctor. Regular monitoring required.");
    }
    return VitalEvaluation(HealthStatus.critical, "High (Stage 2)", Colors.red,
        "Seek medical advice immediately.");
  }

  // --- HEART RATE ---
  static VitalEvaluation evaluateHR(int hr) {
    if (hr == 0) return _error();

    if (hr < 60) {
      return VitalEvaluation(HealthStatus.low, "Low (Bradycardia)", Colors.blue,
          "Normal for athletes. If dizzy, seek help.");
    }
    if (hr <= 100) {
      return VitalEvaluation(HealthStatus.normal, "Normal",
          AppColors.brandGreen, "Heart rate is within healthy range.");
    }
    return VitalEvaluation(
        HealthStatus.critical,
        "High (Tachycardia)",
        Colors.red,
        "Rest and relax. Avoid caffeine. If chest pain occurs, call emergency.");
  }

  // --- OXYGEN (SpO2) ---
  static VitalEvaluation evaluateSpO2(int spo2) {
    if (spo2 == 0) return _error();

    if (spo2 >= 95) {
      return VitalEvaluation(HealthStatus.normal, "Normal",
          AppColors.brandGreen, "Lungs are functioning well.");
    }
    if (spo2 >= 91) {
      return VitalEvaluation(HealthStatus.warning, "Low (Hypoxia Risk)",
          Colors.orange, "Sit upright. Take deep breaths. Monitor closely.");
    }
    return VitalEvaluation(HealthStatus.critical, "Critical Hypoxia",
        Colors.red, "Seek emergency care immediately.");
  }

  // --- TEMPERATURE ---
  static VitalEvaluation evaluateTemp(double temp) {
    if (temp == 0) return _error();

    if (temp < 36.0) {
      return VitalEvaluation(HealthStatus.low, "Low (Hypothermia)", Colors.blue,
          "Keep warm. Drink warm fluids.");
    }
    if (temp <= 37.5) {
      return VitalEvaluation(HealthStatus.normal, "Normal",
          AppColors.brandGreen, "Body temperature is healthy.");
    }
    if (temp <= 38.5) {
      return VitalEvaluation(HealthStatus.warning, "Fever (Low Grade)",
          Colors.orange, "Stay hydrated and rest. Monitor temp.");
    }
    return VitalEvaluation(HealthStatus.critical, "High Fever", Colors.red,
        "Take paracetamol if advised. Seek help if persisting.");
  }

  // --- BMI ---
  static VitalEvaluation evaluateBMI(double bmi) {
    if (bmi == 0) return _error();

    if (bmi < 18.5) {
      return VitalEvaluation(HealthStatus.warning, "Underweight", Colors.blue,
          "Consult a nutritionist for a balanced diet.");
    }
    if (bmi < 25.0) {
      return VitalEvaluation(HealthStatus.normal, "Normal Weight",
          AppColors.brandGreen, "Maintain your current activity and diet.");
    }
    if (bmi < 30.0) {
      return VitalEvaluation(HealthStatus.warning, "Overweight", Colors.orange,
          "Consider 30 mins of daily exercise.");
    }
    return VitalEvaluation(HealthStatus.critical, "Obese", Colors.red,
        "Consult a doctor for a weight management plan.");
  }

  static VitalEvaluation _error() {
    return VitalEvaluation(HealthStatus.error, "Error", Colors.grey,
        "Sensor read error. Please retry.");
  }
}
