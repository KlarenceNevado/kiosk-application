import '../../features/auth/models/user_model.dart';
import '../../features/health_check/models/vital_signs_model.dart';

class HealthThresholds {
  /// Evaluates vitals based on age and gender and returns a list of risk factors.
  /// Uses WHO and AHA general clinical guidelines.
  static List<String> evaluate(User user, VitalSigns vitals) {
    List<String> reasons = [];
    int age = _calculateAge(user.dateOfBirth);
    String gender = user.gender.toLowerCase();

    // 1. SpO2 (Oxygen) - Universal
    if (vitals.oxygen > 0) {
      if (vitals.oxygen < 90) {
        reasons.add("Critical Low O2 (${vitals.oxygen}%)");
      } else if (vitals.oxygen < 95) {
        reasons.add("Low O2 (${vitals.oxygen}%)");
      }
    }

    // 2. Temperature - Universal
    if (vitals.temperature > 0) {
      if (vitals.temperature >= 38.0) {
        reasons.add("Fever (${vitals.temperature}°C)");
      } else if (vitals.temperature < 35.0) {
        reasons.add("Hypothermia (${vitals.temperature}°C)");
      }
    }

    // 3. Blood Pressure
    int sys = vitals.systolicBP;
    int dia = vitals.diastolicBP;
    
    if (sys > 0 && dia > 0) {
      int sysHighLimit = 140;
      int diaHighLimit = 90;
      int sysLowLimit = 90;
      int diaLowLimit = 60;

      if (age <= 1) {
        sysHighLimit = 104; diaHighLimit = 56;
        sysLowLimit = 72; diaLowLimit = 37;
      } else if (age <= 3) {
        sysHighLimit = 106; diaHighLimit = 63;
        sysLowLimit = 86; diaLowLimit = 42;
      } else if (age <= 5) {
        sysHighLimit = 112; diaHighLimit = 72;
        sysLowLimit = 89; diaLowLimit = 46;
      } else if (age <= 12) {
        sysHighLimit = 120; diaHighLimit = 80;
        sysLowLimit = 97; diaLowLimit = 57;
      } else if (age <= 17) {
        sysHighLimit = 131; diaHighLimit = 83;
        sysLowLimit = 110; diaLowLimit = 64;
      } else if (age >= 65) {
        sysHighLimit = 150; diaHighLimit = 90; // Slightly higher acceptable for elderly
        sysLowLimit = 90; diaLowLimit = 60;
      } else {
        // Adult 18-64
        sysHighLimit = 140; diaHighLimit = 90;
        sysLowLimit = 90; diaLowLimit = 60;
      }

      if (sys >= sysHighLimit || dia >= diaHighLimit) {
        reasons.add("High BP ($sys/$dia)");
      } else if (sys <= sysLowLimit || dia <= diaLowLimit) {
        reasons.add("Low BP ($sys/$dia)");
      }
    }

    // 4. Heart Rate (BPM)
    int hr = vitals.heartRate;
    if (hr > 0) {
      int hrHighLimit = 100;
      int hrLowLimit = 60;

      if (age <= 1) {
        hrHighLimit = 160; hrLowLimit = 100;
      } else if (age <= 3) {
        hrHighLimit = 150; hrLowLimit = 90;
      } else if (age <= 5) {
        hrHighLimit = 140; hrLowLimit = 80;
      } else if (age <= 12) {
        hrHighLimit = 120; hrLowLimit = 70;
      } else if (age <= 17) {
        hrHighLimit = 100; hrLowLimit = 60;
      } else {
        // Adults
        if (gender == 'female') {
          hrHighLimit = 105; hrLowLimit = 65;
        } else {
          hrHighLimit = 100; hrLowLimit = 60;
        }
      }

      if (hr >= hrHighLimit) {
        reasons.add("High Heart Rate ($hr bpm)");
      } else if (hr <= hrLowLimit) {
        reasons.add("Low Heart Rate ($hr bpm)");
      }
    }

    // 5. BMI
    if (vitals.bmi != null && vitals.bmi! > 0) {
      double bmi = vitals.bmi!;
      if (age >= 18) {
        // Adult BMI (WHO Standard)
        if (bmi >= 30.0) {
          reasons.add("Obesity Risk (BMI: ${bmi.toStringAsFixed(1)})");
        } else if (bmi < 18.5) {
          reasons.add("Underweight (BMI: ${bmi.toStringAsFixed(1)})");
        }
      } else {
        // Child BMI - static approximation
        if (bmi >= 28.0) {
          reasons.add("High BMI for age (${bmi.toStringAsFixed(1)})");
        } else if (bmi < 14.0) {
          reasons.add("Low BMI for age (${bmi.toStringAsFixed(1)})");
        }
      }
    } else if (vitals.bmiCategory == "Obese") {
      reasons.add("Obesity Risk");
    }

    return reasons;
  }

  static bool isCritical(User user, VitalSigns vitals) {
    if (vitals.status != 'pending') return false; // Already triaged/verified
    return evaluate(user, vitals).isNotEmpty;
  }

  static int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}
