import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// CORE
import 'package:kiosk_application/core/constants/app_colors.dart';
import 'package:kiosk_application/core/services/database/sync/vitals_sync_handler.dart';
import 'package:kiosk_application/core/utils/vital_validator.dart';
import 'package:kiosk_application/core/widgets/flow_animated_button.dart';

// MODELS
import 'package:kiosk_application/features/health_check/models/vital_signs_model.dart';

class PublicResultsScreen extends StatefulWidget {
  final String recordId;

  const PublicResultsScreen({
    super.key,
    required this.recordId,
  });

  @override
  State<PublicResultsScreen> createState() => _PublicResultsScreenState();
}

class _PublicResultsScreenState extends State<PublicResultsScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  VitalSigns? _record;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecord();
  }

  Future<void> _fetchRecord() async {
    try {
      final syncHandler =
          Provider.of<VitalsSyncHandler>(context, listen: false);
      final record = await syncHandler.fetchVitalSignById(widget.recordId);

      if (mounted) {
        setState(() {
          _record = record;
          _isLoading = false;
          if (record == null) {
            _error =
                "Record not found. It may still be syncing from the Kiosk.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "An error occurred while fetching your report.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_record == null) return;

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final record = _record!;
      final dateStr =
          DateFormat('MMMM dd, yyyy - hh:mm a').format(record.timestamp);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // PDF Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("ISLA VERDE HEALTH KIOSK",
                              style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.green900)),
                          pw.Text("Official Clinical Summary Report",
                              style: const pw.TextStyle(
                                  fontSize: 14, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("RECORD ID",
                              style: const pw.TextStyle(
                                  fontSize: 10, color: PdfColors.grey500)),
                          pw.Text(record.id.toUpperCase(),
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 2, color: PdfColors.green),
                  pw.SizedBox(height: 20),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("DATE: $dateStr",
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text("SOURCE: Isla Verde Community Kiosk #1",
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 40),

                  pw.Text("CLINICAL MEASUREMENTS",
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _buildPdfHeaderRow(),
                      _buildPdfRow(
                          "Blood Pressure",
                          "${record.systolicBP}/${record.diastolicBP}",
                          "mmHg",
                          VitalValidator.evaluateBP(
                              record.systolicBP, record.diastolicBP)),
                      _buildPdfRow("Heart Rate", "${record.heartRate}", "bpm",
                          VitalValidator.evaluateHR(record.heartRate)),
                      _buildPdfRow("Oxygen (SpO2)", "${record.oxygen}", "%",
                          VitalValidator.evaluateSpO2(record.oxygen)),
                      _buildPdfRow("Temperature", "${record.temperature}", "°C",
                          VitalValidator.evaluateTemp(record.temperature)),
                      if (record.bmi != null)
                        _buildPdfRow("BMI", record.bmi!.toStringAsFixed(1),
                            "kg/m²", VitalValidator.evaluateBMI(record.bmi!)),
                    ],
                  ),

                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          "Generated via Isla Verde Digital Handover System",
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey500)),
                      pw.Text("Verification: ${record.id.substring(0, 8)}",
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Medical_Report_${record.id.substring(0, 8)}.pdf',
      );
    } catch (e) {
      debugPrint("PDF Error: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.TableRow _buildPdfHeaderRow() {
    return pw.TableRow(
      children: [
        pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey100,
            child: pw.Text("VITAL SIGN",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey100,
            child: pw.Text("VALUE",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey100,
            child: pw.Text("STATUS",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  pw.TableRow _buildPdfRow(
      String label, String value, String unit, VitalEvaluation eval) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text("$value $unit")),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(eval.label.toUpperCase())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildSuccess(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.brandGreen),
          const SizedBox(height: 24),
          Text("Retrieving your report...",
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_problem_rounded,
                color: Colors.orange, size: 64),
            const SizedBox(height: 24),
            const Text("Something went wrong",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 16, height: 1.5)),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _fetchRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Try Again"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final record = _record!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: AppColors.brandGreen,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text("Medical Summary",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandGreen, Color(0xFF1B5E20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          actions: [
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
              )
            else
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white),
                onPressed: _exportPdf,
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildMetricCard(
                  title: "Blood Pressure",
                  value: "${record.systolicBP}/${record.diastolicBP}",
                  unit: "mmHg",
                  icon: Icons.speed_rounded,
                  eval: VitalValidator.evaluateBP(
                      record.systolicBP, record.diastolicBP),
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  title: "Heart Rate",
                  value: "${record.heartRate}",
                  unit: "bpm",
                  icon: Icons.favorite_rounded,
                  eval: VitalValidator.evaluateHR(record.heartRate),
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  title: "Oxygen",
                  value: "${record.oxygen}",
                  unit: "%",
                  icon: Icons.air_rounded,
                  eval: VitalValidator.evaluateSpO2(record.oxygen),
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  title: "Temperature",
                  value: "${record.temperature}",
                  unit: "°C",
                  icon: Icons.thermostat_rounded,
                  eval: VitalValidator.evaluateTemp(record.temperature),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FlowAnimatedButton(
                    child: ElevatedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text("Download Formal PDF Report"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required VitalEvaluation eval,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: eval.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                Text("$value $unit",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(eval.label.toUpperCase(),
              style: TextStyle(color: eval.color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
