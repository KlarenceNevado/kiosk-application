import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/models/user_model.dart';
import '../../health_check/models/vital_signs_model.dart';

class PatientPdfService {
  static Future<void> generateAndPrintRecord({
    required User patient,
    required VitalSigns record,
  }) async {
    String maskPhone(String phone) {
      if (phone.length < 6) return phone;
      final first2 = phone.substring(0, 2);
      final last4 = phone.substring(phone.length - 4);
      final masking = '*' * (phone.length - 6);
      return "$first2$masking$last4";
    }

    final pdf = pw.Document();

    final dateString =
        DateFormat('MMMM dd, yyyy - hh:mm a').format(record.timestamp);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text("Barangay Health Checkup Record",
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Patient Details",
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800)),
              pw.Divider(),
              pw.Text("Name: ${patient.fullName}",
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text("Phone Number: ${maskPhone(patient.phoneNumber)}",
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text("Age: ${patient.age} / Gender: ${patient.gender}",
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 30),
              pw.Text("Checkup Results",
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800)),
              pw.Divider(),
              pw.Text("Date & Time: $dateString",
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildMetricRow("Heart Rate", "${record.heartRate} bpm"),
              _buildMetricRow("Blood Oxygen (SpO2)", "${record.oxygen}%"),
              _buildMetricRow("Blood Pressure",
                  "${record.systolicBP}/${record.diastolicBP} mmHg"),
              _buildMetricRow("Temperature", "${record.temperature} °C"),
              _buildMetricRow(
                  "BMI",
                  record.bmi != null
                      ? "${record.bmi!.toStringAsFixed(1)} (${record.bmiCategory ?? 'N/A'})"
                      : "N/A"),
              pw.SizedBox(height: 40),
              pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text("--- Official Health Record ---",
                      style: const pw.TextStyle(color: PdfColors.grey)))
            ],
          );
        },
      ),
    );

    // Save/Print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Health_Record_${patient.firstName}_${DateFormat('yyyyMMdd').format(record.timestamp)}.pdf',
    );
  }

  static pw.Widget _buildMetricRow(String label, String value) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Text(value,
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ));
  }
}
