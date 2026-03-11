import 'dart:io';
// FIXED: Removed unused import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import '../../../features/health_check/models/vital_signs_model.dart';

class PdfReportService {
  Future<void> generateAndOpenReport(VitalSigns data) async {
    final pdf = pw.Document();

    // Professional Medical Styling
    const baseColor = PdfColors.teal;
    final titleStyle = pw.TextStyle(
        fontSize: 26, fontWeight: pw.FontWeight.bold, color: baseColor);
    const subtitleStyle = pw.TextStyle(fontSize: 14, color: PdfColors.grey700);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // 1. Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("ISLAND HEALTH KIOSK", style: titleStyle),
                      pw.Text("Rural Health Unit • Automated Screening",
                          style: subtitleStyle),
                      pw.SizedBox(height: 4),
                      pw.Text("Barangay Health Center",
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey)),
                    ]),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: baseColor, width: 2),
                      borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text("OFFICIAL RECORD",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, color: baseColor)),
                )
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 2, color: baseColor),
            pw.SizedBox(height: 20),

            // 2. Patient Demographics & Metadata
            pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoColumn(
                          "PATIENT ID", data.id.substring(0, 8).toUpperCase()),
                      _buildInfoColumn("DATE",
                          DateFormat('MMMM dd, yyyy').format(data.timestamp)),
                      _buildInfoColumn(
                          "TIME", DateFormat('hh:mm a').format(data.timestamp)),
                      _buildInfoColumn("REPORT ID",
                          "#${data.timestamp.millisecondsSinceEpoch.toString().substring(8)}"),
                    ])),
            pw.SizedBox(height: 30),

            // 3. Clinical Vitals Table
            pw.Text("VITAL SIGNS EXAMINATION",
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black)),
            pw.SizedBox(height: 10),

            pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Metric
                  1: const pw.FlexColumnWidth(2), // Result
                  2: const pw.FlexColumnWidth(1), // Unit
                  3: const pw.FlexColumnWidth(2), // Reference
                  4: const pw.FlexColumnWidth(2), // Status
                },
                children: [
                  // Header
                  pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.teal50),
                      children: [
                        _tableHeader("METRIC"),
                        _tableHeader("YOUR RESULT"),
                        _tableHeader("UNIT"),
                        _tableHeader("REFERENCE RANGE"),
                        _tableHeader("STATUS"),
                      ]),
                  // Rows
                  _buildTableRow("Heart Rate", "${data.heartRate}", "bpm",
                      "60 - 100", _getHRStatus(data.heartRate)),
                  _buildTableRow(
                      "Blood Pressure",
                      "${data.systolicBP}/${data.diastolicBP}",
                      "mmHg",
                      "< 120/80",
                      _getBPStatus(data.systolicBP, data.diastolicBP)),
                  _buildTableRow("Oxygen Saturation", "${data.oxygen}", "%",
                      "95 - 100", _getO2Status(data.oxygen)),
                  _buildTableRow("Body Temp", "${data.temperature}", "°C",
                      "36.5 - 37.5", _getTempStatus(data.temperature)),
                ]),

            pw.SizedBox(height: 30),

            // 4. Interpretation / Notes
            pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("INTERPRETATION GUIDE:",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          "• Normal: Result falls within the standard healthy range.",
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                          "• Elevated/High/Low: Result deviates from the standard range. Monitoring or consultation recommended.",
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 8),
                      pw.Text(
                          "NOTE: Factors such as stress, diet, and physical activity immediately prior to testing can affect results.",
                          style: pw.TextStyle(
                              fontSize: 9, fontStyle: pw.FontStyle.italic)),
                    ])),

            pw.Spacer(),

            // 5. Disclaimer & Signature
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("DISCLAIMER:",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.Text(
                            "This automated report is for screening purposes only and is NOT a medical diagnosis.",
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(
                            "Please consult a licensed physician for professional medical advice.",
                            style: const pw.TextStyle(fontSize: 8)),
                      ]),
                  pw.Column(children: [
                    pw.Container(width: 100, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text("Automated System Verified",
                        style: const pw.TextStyle(fontSize: 8)),
                  ])
                ]),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Page 1 of 1",
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            )
          ];
        },
      ),
    );

    // Save and Open
    final output = await getApplicationDocumentsDirectory();
    final file =
        File("${output.path}/Medical_Report_${data.id.substring(0, 6)}.pdf");
    await file.writeAsBytes(await pdf.save());

    // Open the PDF viewer
    await OpenFile.open(file.path);
  }

  // --- WIDGET HELPERS ---

  pw.Widget _buildInfoColumn(String label, String value) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ]);
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.teal900)),
    );
  }

  pw.TableRow _buildTableRow(String metric, String result, String unit,
      String refRange, String status) {
    PdfColor statusColor = PdfColors.black;
    bool isBold = false;

    if (status.contains("High") ||
        status.contains("Low") ||
        status.contains("Fever")) {
      statusColor = PdfColors.red700;
      isBold = true;
    } else if (status.contains("Elevated")) {
      statusColor = PdfColors.orange700;
    } else {
      statusColor = PdfColors.green700;
    }

    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(metric)),
      pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(result,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(unit)),
      pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(refRange,
              style:
                  const pw.TextStyle(color: PdfColors.grey700, fontSize: 9))),
      pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(status.toUpperCase(),
              style: pw.TextStyle(
                  color: statusColor,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 9))),
    ]);
  }

  // --- LOGIC HELPERS ---

  String _getBPStatus(int sys, int dia) {
    if (sys < 120 && dia < 80) return "Normal";
    if (sys >= 140 || dia >= 90) return "High (Stage 2)";
    if (sys >= 130 || dia >= 80) return "High (Stage 1)";
    return "Elevated";
  }

  String _getHRStatus(int hr) {
    if (hr >= 60 && hr <= 100) return "Normal";
    if (hr > 100) return "High (Tachycardia)";
    return "Low (Bradycardia)";
  }

  String _getO2Status(int o2) {
    if (o2 >= 95) return "Normal";
    if (o2 >= 90) return "Low";
    return "Critical";
  }

  String _getTempStatus(double temp) {
    if (temp >= 36.5 && temp <= 37.5) return "Normal";
    if (temp > 37.5) return "Fever";
    return "Low";
  }
}
