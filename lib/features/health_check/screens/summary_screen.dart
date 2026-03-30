import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

// CORE
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/flow_animated_button.dart';
// NEW: Import the Medical Intelligence
import '../../../core/utils/vital_validator.dart';
import '../../../core/services/system/app_environment.dart';

// DATA & SERVICES
import '../../health_check/models/vital_signs_model.dart';
import '../../user_history/domain/i_history_repository.dart';

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
    _showQrHandoverDialog(data);
  }

  void _showQrHandoverDialog(VitalSigns data) {
    // STOP the auto-redirect timer while dialog is open
    _timer?.cancel();

    showDialog(
      context: context,
      builder: (context) => DigitalHandoverDialog(
        data: data,
        onClose: () {
          Navigator.of(context).pop();
          _startAutoRedirect(); // Resume countdown
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final history = context.watch<IHistoryRepository>();
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
                              Icons.qr_code_scanner_rounded,
                              "Get Digital Copy",
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

// --- DIGITAL HANDOVER DIALOG ---
class DigitalHandoverDialog extends StatelessWidget {
  final VitalSigns data;
  final VoidCallback onClose;

  const DigitalHandoverDialog({
    super.key,
    required this.data,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Generate the PWA URL
    // Robust URL construction for GitHub Pages (Hash Strategy)
    String pwaBase = AppEnvironment().pwaUrl;
    if (!pwaBase.contains('/#/')) {
      pwaBase = pwaBase.endsWith('/') ? '$pwaBase#' : '$pwaBase/#';
    }
    // Ensure no double slashes after the hash
    final String resultUrl = "${pwaBase.replaceAll(RegExp(r'/$'), '')}/results/${data.id}";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 24,
      backgroundColor: Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.brandGreenLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phonelink_ring_rounded, 
                    color: AppColors.brandGreen, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Digital Health Report", 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.brandDark)),
                      Text("Take your records with you", 
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 32),

            // 2. QR Code Frame
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: QrImageView(
                data: resultUrl,
                version: QrVersions.auto,
                size: 240.0,
                gapless: false,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.brandDark,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.brandGreen,
                ),
                embeddedImage: const AssetImage('assets/icons/patient_icon.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(40, 40),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 3. Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Open your phone's CAMERA app and point it at the QR code to view your digital summary instantly.",
                      style: TextStyle(fontSize: 14, color: AppColors.brandDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 4. Close/Finish Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Got it, thanks!", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
