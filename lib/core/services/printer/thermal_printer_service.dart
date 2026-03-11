import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../features/health_check/models/vital_signs_model.dart';

// NOTE: This service is in VIRTUAL MODE to prevent Windows build crashes.
// It generates the receipt data but prints to the Debug Console instead of a USB port.

class ThermalPrinterService {
  static final ThermalPrinterService _instance =
      ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  /// Initialize (Simulated)
  Future<void> init(String portName) async {
    debugPrint("🖨️ VIRTUAL PRINTER: Initialized on $portName (Ready)");
  }

  /// Generate and 'Print' Receipt
  Future<void> printReceipt(VitalSigns data) async {
    debugPrint("🖨️ VIRTUAL PRINTER: Generating Receipt...");

    try {
      // 1. Setup Generator
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // 2. Build Receipt Layout
      bytes += generator.text('HEALTH KIOSK',
          styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.text('Official Result',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      // Data
      bytes +=
          generator.text('Date: ${data.timestamp.toString().split('.')[0]}');
      bytes += generator.text('Patient ID: ${data.id.substring(0, 8)}');
      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(text: 'Heart Rate:', width: 6),
        PosColumn(
            text: '${data.heartRate} bpm',
            width: 6,
            styles: const PosStyles(bold: true)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'BP:', width: 6),
        PosColumn(
            text: '${data.systolicBP}/${data.diastolicBP}',
            width: 6,
            styles: const PosStyles(bold: true)),
      ]);

      // Footer
      bytes += generator.feed(2);
      bytes += generator.text('Consult a doctor.',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // 3. SIMULATE PRINTING
      // Since we don't have a real USB port driver installed, we just log the success.
      await Future.delayed(
          const Duration(seconds: 2)); // Simulate printing time
      debugPrint(
          "✅ PRINT SUCCESS: Sent ${bytes.length} bytes to virtual output.");
    } catch (e) {
      debugPrint("❌ Print Error: $e");
    }
  }
}
