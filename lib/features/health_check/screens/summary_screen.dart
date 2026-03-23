import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// CORE
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/flow_animated_button.dart';
// NEW: Import the Medical Intelligence
import '../../../core/utils/vital_validator.dart';

// DATA & SERVICES
import '../../health_check/models/vital_signs_model.dart';
import '../../user_history/data/history_repository.dart';
import '../../../core/services/system/pdf_report_service.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Timer? _timer;
  int _countdown = 90; // Longer time to read advice

  @override
  void initState() {
    super.initState();
    _startAutoRedirect();
  }

  void _startAutoRedirect() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown <= 1) {
          _goHome();
        } else {
          _countdown--;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    _timer?.cancel();
    if (mounted) context.go(AppRoutes.home);
  }

  void _handlePdf(VitalSigns data) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Generating PDF Report..."),
        duration: Duration(seconds: 2)));
    await PdfReportService().generateAndOpenReport(data);
  }


  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryRepository>();
    final latestRecord =
        history.records.isNotEmpty ? history.records.first : null;

    if (latestRecord == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // --- MEDICAL REPORT CARD ---
                Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20)
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppColors.brandGreen,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.medical_services_outlined,
                                color: Colors.white, size: 32),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("CLINICAL SUMMARY",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text("Automated Health Kiosk",
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                            Text(
                                DateFormat('MMM dd, hh:mm a')
                                    .format(latestRecord.timestamp),
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),

                      // Vitals Grid (Using Centralized Validator)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            _buildVitalRow(
                                "Blood Pressure",
                                "${latestRecord.systolicBP}/${latestRecord.diastolicBP}",
                                "mmHg",
                                VitalValidator.evaluateBP(
                                    latestRecord.systolicBP,
                                    latestRecord.diastolicBP)),
                            const Divider(height: 32),
                            _buildVitalRow(
                                "Heart Rate",
                                "${latestRecord.heartRate}",
                                "bpm",
                                VitalValidator.evaluateHR(
                                    latestRecord.heartRate)),
                            const Divider(height: 32),
                            _buildVitalRow(
                                "Oxygen Saturation",
                                "${latestRecord.oxygen}",
                                "%",
                                VitalValidator.evaluateSpO2(
                                    latestRecord.oxygen)),
                            const Divider(height: 32),
                            _buildVitalRow(
                                "Temperature",
                                "${latestRecord.temperature}",
                                "°C",
                                VitalValidator.evaluateTemp(
                                    latestRecord.temperature)),
                            if (latestRecord.bmi != null) ...[
                              const Divider(height: 32),
                              _buildVitalRow(
                                  "Body Mass Index",
                                  "${latestRecord.bmi?.toStringAsFixed(1)}",
                                  "kg/m²",
                                  VitalValidator.evaluateBMI(
                                      latestRecord.bmi!)),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- SMART ADVICE CARDS ---
                // Automatically shows advice based on abnormal results
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      _buildAdviceCard(VitalValidator.evaluateBP(
                          latestRecord.systolicBP, latestRecord.diastolicBP)),
                      _buildAdviceCard(
                          VitalValidator.evaluateHR(latestRecord.heartRate)),
                      _buildAdviceCard(
                          VitalValidator.evaluateSpO2(latestRecord.oxygen)),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // --- ACTIONS ---
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: [
                      Expanded(
                          child: FlowAnimatedButton(
                              child: _buildActionButton(
                                  Icons.picture_as_pdf_rounded,
                                  "Download PDF Report",
                                  () => _handlePdf(latestRecord),
                                  isPrimary: false))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: FlowAnimatedButton(
                              child: _buildActionButton(
                                  Icons.home_rounded, "Finish Check-up", _goHome,
                                  isPrimary: true))),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text("Screen closing in $_countdown seconds",
                    style: TextStyle(color: Colors.grey[400]))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalRow(
      String label, String value, String unit, VitalEvaluation eval) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold))),
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDark)),
        const SizedBox(width: 4),
        Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: eval.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: eval.color),
          ),
          child: Text(
            eval.label.toUpperCase(),
            style: TextStyle(
                color: eval.color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Shows a card only if there is a warning/critical status
  Widget _buildAdviceCard(VitalEvaluation eval) {
    if (eval.status == HealthStatus.normal) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: eval.color, width: 6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: eval.color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                eval.advice,
                style: TextStyle(
                    color: Colors.grey[800], fontSize: 16, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap,
      {required bool isPrimary}) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isPrimary
            ? null
            : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: isPrimary ? Colors.white : AppColors.brandDark,
                    size: 28),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        color: isPrimary ? Colors.white : AppColors.brandDark,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
