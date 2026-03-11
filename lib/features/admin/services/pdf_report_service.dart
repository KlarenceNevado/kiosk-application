import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/models/user_model.dart';
import '../../health_check/models/vital_signs_model.dart';

class PdfReportService {
  static Future<void> generateAndPrintMonthlyReport({
    required List<User> users,
    required List<VitalSigns> records,
  }) async {
    final pdf = pw.Document();

    // 1. Calculate Summary Stats
    final thisMonth = DateTime.now().month;
    final thisYear = DateTime.now().year;

    final currentMonthRecords = records
        .where((r) =>
            r.phtTimestamp.month == thisMonth &&
            r.phtTimestamp.year == thisYear)
        .toList();

    int totalScreenings = currentMonthRecords.length;

    // Find High Risk Patients
    final Map<String, VitalSigns> userLatestRecord = {};
    for (var r in currentMonthRecords) {
      if (!userLatestRecord.containsKey(r.userId)) {
        userLatestRecord[r.userId] = r;
      }
    }

    List<Map<String, dynamic>> highRisk = [];
    userLatestRecord.forEach((userId, vitals) {
      if (vitals.systolicBP > 140 || vitals.oxygen < 92) {
        final user = users.firstWhere((u) => u.id == userId,
            orElse: () => User(
                id: '',
                firstName: 'Unknown',
                middleInitial: '',
                lastName: '',
                sitio: '',
                phoneNumber: '',
                pinCode: '',
                dateOfBirth: DateTime.now(),
                gender: ''));
        highRisk.add({'user': user, 'vitals': vitals});
      }
    });

    // Sort by most critical BP
    highRisk.sort((a, b) => (b['vitals'] as VitalSigns)
        .systolicBP
        .compareTo((a['vitals'] as VitalSigns).systolicBP));
    final topHighRisk = highRisk.take(10).toList();

    // 2. Build PDF Document Stack
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(thisMonth, thisYear),
            pw.SizedBox(height: 24),
            _buildSummaryRow(users.length, totalScreenings, highRisk.length),
            pw.SizedBox(height: 32),
            pw.Text("Top High-Risk Individuals (Needs Attention)",
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800)),
            pw.SizedBox(height: 12),
            _buildHighRiskTable(topHighRisk),
            pw.SizedBox(height: 32),
            pw.Text("Monthly Activity Log",
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildActivityTable(users, currentMonthRecords.take(20).toList()),
            pw.SizedBox(height: 20),
            pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text("--- End of Report ---",
                    style: const pw.TextStyle(color: PdfColors.grey)))
          ];
        },
      ),
    );

    // 3. Initiate Print / Save Dialog via OS
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Barangay_Health_Report_${thisYear}_$thisMonth.pdf',
    );
  }

  static pw.Widget _buildHeader(int month, int year) {
    return pw
        .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text("Barangay Health & Wellness",
          style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900)),
      pw.SizedBox(height: 4),
      pw.Text("Automated System Analytics Report",
          style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
      pw.SizedBox(height: 8),
      pw.Text("Generated for: Month $month, $year",
          style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
      pw.Divider(thickness: 2, color: PdfColors.blueGrey100),
    ]);
  }

  static pw.Widget _buildSummaryRow(
      int totalPatients, int monthScreenings, int totalHighRisk) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildStatBox(
              "Total Registered", "$totalPatients", PdfColors.blue800),
          _buildStatBox(
              "Screenings This Month", "$monthScreenings", PdfColors.green800),
          _buildStatBox("High-Risk Alerts", "$totalHighRisk", PdfColors.red800),
        ]);
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
        width: 130,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: color, width: 2),
            borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              pw.SizedBox(height: 4),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center)
            ]));
  }

  static pw.Widget _buildHighRiskTable(List<Map<String, dynamic>> highRisk) {
    if (highRisk.isEmpty) {
      return pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Text("No high-risk patients detected this month."));
    }

    return pw.TableHelper.fromTextArray(
        context: null,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.red100),
        headerHeight: 30,
        cellHeight: 30,
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
        },
        headers: ["Patient Name", "Phone", "BP (Sys/Dia)", "SpO2"],
        data: highRisk.map((h) {
          final user = h['user'] as User;
          final v = h['vitals'] as VitalSigns;
          return [
            user.fullName,
            user.phoneNumber,
            "${v.systolicBP}/${v.diastolicBP}",
            "${v.oxygen}%"
          ];
        }).toList());
  }

  static pw.Widget _buildActivityTable(
      List<User> users, List<VitalSigns> records) {
    return pw.TableHelper.fromTextArray(
        context: null,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
        headers: ["Date", "Time", "Patient ID", "Heart Rate", "BMI Category"],
        data: records.map((r) {
          return [
            "${r.phtTimestamp.year}-${r.phtTimestamp.month.toString().padLeft(2, '0')}-${r.phtTimestamp.day.toString().padLeft(2, '0')}",
            "${r.phtTimestamp.hour.toString().padLeft(2, '0')}:${r.phtTimestamp.minute.toString().padLeft(2, '0')}",
            r.userId.length > 8 ? r.userId.substring(0, 8) : r.userId,
            "${r.heartRate} bpm",
            r.bmiCategory ?? "N/A"
          ];
        }).toList());
  }
}
