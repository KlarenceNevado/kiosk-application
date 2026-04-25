import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/models/user_model.dart';
import '../../health_check/models/vital_signs_model.dart';

class PdfReportService {
  // DEPRECATED: Standard Monthly Report removed as per user request for formal letter format.
  // Use generateOfficialLGUReport instead.

  static Future<void> generateOfficialLGUReport({
    required List<User> users,
    required List<VitalSigns> records,
    required DateTime startDate,
    required DateTime endDate,
    String? sitio,
    String? gender,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('MMMM dd, yyyy');
    
    final filtered = records.where((r) {
      final inDate = r.phtTimestamp.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                     r.phtTimestamp.isBefore(endDate.add(const Duration(days: 1)));
      
      final user = users.firstWhere((u) => u.id == r.userId, orElse: () => User.empty());
      
      final sitioMatch = sitio == null || sitio == "ALL SITIOS" || user.sitio == sitio;
      final genderMatch = gender == null || gender == "ALL GENDERS" || user.gender.toUpperCase() == gender.toUpperCase();
      
      return inDate && sitioMatch && genderMatch;
    }).toList();

    int highRiskCount = filtered.where((r) => r.systolicBP > 140 || r.oxygen < 92).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (pw.Context context) {
          return [
            // Letterhead
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text("REPUBLIC OF THE PHILIPPINES", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text("PROVINCE OF BATANGAS", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("CITY HEALTH OFFICE - ISLA VERDE DISTRICT", style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text("OFFICE OF THE BARANGAY HEALTH WORKER", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Divider(thickness: 1),
              ]
            ),
            pw.SizedBox(height: 24),
            
            // Letter Meta
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Date: ${df.format(DateTime.now())}")),
            pw.SizedBox(height: 24),
            
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("THE CITY HEALTH OFFICER", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("City Health Main Office"),
                pw.Text("Batangas City, Philippines"),
              ]
            ),
            pw.SizedBox(height: 24),
            
            pw.Text("SUBJECT: BARANGAY HEALTH SITUATION REPORT (${df.format(startDate)} TO ${df.format(endDate)})", 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 24),
            
            pw.Text("Dear Sir/Madam:"),
            pw.SizedBox(height: 12),
            pw.Paragraph(
              text: "Respectfully submitting herewith the comprehensive health screening report for Barangay Isla Verde (${sitio ?? "All Sitios"}) for the period of ${df.format(startDate)} to ${df.format(endDate)}. This data was captured via the Automated Kiosk System and has been verified by the assigned Barangay Health Workers (BHWs).",
            ),
            
            pw.SizedBox(height: 12),
            pw.Text("SUMMARY OF CLINICAL FINDINGS:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Bullet(text: "Total Residents Screened: ${filtered.length}"),
            pw.Bullet(text: "High-Risk Hypertensive/Hypoxic Cases Identified: $highRiskCount"),
            pw.Bullet(text: "Target Demographic: General Population"),
            
            pw.SizedBox(height: 24),
            pw.Text("DETAILED CLINICAL LOG:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildOfficialTable(users, filtered),
            
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Prepared by:", style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 150, 
                      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))
                    ),
                    pw.Text("Barangay Health Worker", style: const pw.TextStyle(fontSize: 10)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Noted by:", style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 150, 
                      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))
                    ),
                    pw.Text("Barangay Chairperson", style: const pw.TextStyle(fontSize: 10)),
                  ]
                ),
              ]
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'LGU_Official_Report_${DateFormat('yyyyMMdd').format(startDate)}.pdf',
    );
  }

  static pw.Widget _buildOfficialTable(List<User> users, List<VitalSigns> records) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ["DATE", "RESIDENT NAME", "SITIO", "BP (SYS/DIA)", "HR", "TEMP", "O2%"],
      data: records.map((r) {
        final user = users.firstWhere((u) => u.id == r.userId, orElse: () => User.empty());
        return [
          DateFormat('MM/dd/yy').format(r.phtTimestamp),
          user.fullName.toUpperCase(),
          user.sitio.toUpperCase(),
          "${r.systolicBP}/${r.diastolicBP}",
          "${r.heartRate}",
          "${r.temperature}",
          "${r.oxygen}%"
        ];
      }).toList(),
    );
  }
}
