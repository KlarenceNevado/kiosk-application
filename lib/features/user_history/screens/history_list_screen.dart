import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// CORE WIDGETS
import '../../../core/widgets/kiosk_scaffold.dart';
import '../../../core/widgets/status_placeholder.dart';
import '../widgets/history_item_tile.dart';

// CORE
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/routes.dart';
import '../../../core/utils/vital_validator.dart';

// DATA
import '../../../features/auth/domain/i_auth_repository.dart';
import '../domain/i_history_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
// NEW: Import Security
import '../../../core/services/security/encryption_service.dart';

class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({super.key});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  // State for the Trend Dashboard
  String _selectedMetric = 'BP';

  // SECURITY STATE
  bool _isPrivacyMode = false; // Default false, user can toggle
  Timer? _privacyTimer;

  @override
  void initState() {
    super.initState();
    // Initialize Encryption
    EncryptionService().init();

    // Auto-enable privacy mode after 15 seconds of inactivity on this screen
    _resetPrivacyTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = context.read<IAuthRepository>().currentUser;
        if (user != null) {
          context.read<IHistoryRepository>().loadUserHistory(user.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _privacyTimer?.cancel();
    super.dispose();
  }

  void _resetPrivacyTimer() {
    _privacyTimer?.cancel();
    _privacyTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_isPrivacyMode) {
        setState(() => _isPrivacyMode = true);
      }
    });
  }

  void _togglePrivacy() {
    setState(() => _isPrivacyMode = !_isPrivacyMode);
    _resetPrivacyTimer();
  }

  @override
  Widget build(BuildContext context) {
    final historyRepo = context.watch<IHistoryRepository>();
    final records = historyRepo.records;
    final isLoading = historyRepo.isLoading;

    return GestureDetector(
      onPanDown: (_) => _resetPrivacyTimer(), // Detect activity
      onTap: _resetPrivacyTimer,
      child: KioskScaffold(
        title: "My Health Trends",
        onBackTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.patientHome);
          }
        },
        actions: [
          // SECURITY TOGGLE
          IconButton(
            icon: Icon(_isPrivacyMode ? Icons.visibility_off : Icons.visibility,
                color: _isPrivacyMode ? Colors.red : AppColors.brandGreen),
            tooltip: _isPrivacyMode ? "Show Data" : "Hide Data (Privacy)",
            onPressed: _togglePrivacy,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            onPressed: () {
              final user = context.read<IAuthRepository>().currentUser;
              if (user != null) {
                context.read<IHistoryRepository>().loadUserHistory(user.id);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brandGreen))
            : records.isEmpty
                ? StatusPlaceholder(
                    icon: Icons.folder_open_rounded,
                    title: "No Records Found",
                    subtitle: "Your health history is empty.",
                    buttonText: "Start First Checkup",
                    onButtonPressed: () => context.go(AppRoutes.healthWizard),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: records.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SECURITY BANNER
                            if (_isPrivacyMode)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            Colors.red.withValues(alpha: 0.3))),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lock,
                                        size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text("Privacy Mode Active: Data is hidden.",
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                            _buildTrendDashboard(records),
                            const SizedBox(height: 32),
                            const Text("Visit Log",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandDark)),
                            const SizedBox(height: 16),
                          ],
                        );
                      } else if (index == records.length + 1) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 40, bottom: 20),
                          child: Center(
                              child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 14, color: Colors.grey),
                              SizedBox(width: 6),
                              Text("End-to-End Encrypted (AES-256)",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          )),
                        );
                      }

                      final record = records[index - 1];

                      // PRIVACY WRAPPER FOR TILES
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _isPrivacyMode
                            ? Stack(
                                children: [
                                  // Blurred Content
                                  ImageFiltered(
                                    imageFilter:
                                        ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: HistoryItemTile(
                                      data: record,
                                      onTap: () {}, // Disable tap when locked
                                    ),
                                  ),
                                  // Lock Overlay
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.lock_outline,
                                            color: Colors.black45, size: 32),
                                      ),
                                    ),
                                  )
                                ],
                              )
                            : HistoryItemTile(
                                data: record,
                                onTap: () => _showRecordDetails(record),
                              ),
                      );
                    },
                  ),
      ),
    );
  }

  // --- 1. TREND DASHBOARD (Smart Averaging) ---
  Widget _buildTrendDashboard(List<VitalSigns> records) {
    if (_isPrivacyMode) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text("Trends Hidden",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text("Tap the eye icon to reveal.",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final recent = records.take(7).toList().reversed.toList();

    String avgValue = "--";

    if (recent.isNotEmpty) {
      if (_selectedMetric == 'HR') {
        final valid = recent.where((r) => r.heartRate > 0).toList();
        if (valid.isNotEmpty) {
          int sum = valid.fold(0, (p, c) => p + c.heartRate);
          avgValue = "${(sum / valid.length).round()} bpm";
        }
      } else if (_selectedMetric == 'O2') {
        final valid = recent.where((r) => r.oxygen > 0).toList();
        if (valid.isNotEmpty) {
          int sum = valid.fold(0, (p, c) => p + c.oxygen);
          avgValue = "${(sum / valid.length).round()}%";
        }
      } else if (_selectedMetric == 'TEMP') {
        final valid = recent.where((r) => r.temperature > 0).toList();
        if (valid.isNotEmpty) {
          double sum = valid.fold(0, (p, c) => p + c.temperature);
          avgValue = "${(sum / valid.length).toStringAsFixed(1)} °C";
        }
      } else if (_selectedMetric == 'BP') {
        final valid = recent.where((r) => r.systolicBP > 0).toList();
        if (valid.isNotEmpty) {
          int sumSys = valid.fold(0, (p, c) => p + c.systolicBP);
          int sumDia = valid.fold(0, (p, c) => p + c.diastolicBP);
          avgValue =
              "${(sumSys / valid.length).round()}/${(sumDia / valid.length).round()}";
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandGreen.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: AppColors.brandGreen),
              const SizedBox(width: 12),
              Text("Health Trends",
                  style: AppTextStyles.h2
                      .copyWith(fontSize: 18, color: AppColors.brandDark)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20)),
                child: Text("AVG: $avgValue",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricToggle("Blood Pressure", 'BP', Colors.blue),
                const SizedBox(width: 8),
                _buildMetricToggle("Heart Rate", 'HR', Colors.red),
                const SizedBox(width: 8),
                _buildMetricToggle("Oxygen", 'O2', Colors.cyan),
                const SizedBox(width: 8),
                _buildMetricToggle("Temp", 'TEMP', Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map((r) => _buildGraphBar(r)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricToggle(String label, String code, Color color) {
    bool isSelected = _selectedMetric == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetric = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildGraphBar(VitalSigns r) {
    double percentage = 0.05;
    Color color = Colors.grey.withValues(alpha: 0.3);
    String label = "";

    if (_selectedMetric == 'BP' && r.systolicBP > 0) {
      percentage = (r.systolicBP - 80) / 100;
      final eval = VitalValidator.evaluateBP(r.systolicBP, r.diastolicBP);
      color = eval.color;
      label = "${r.systolicBP}";
    } else if (_selectedMetric == 'HR' && r.heartRate > 0) {
      percentage = (r.heartRate - 40) / 120;
      final eval = VitalValidator.evaluateHR(r.heartRate);
      color = eval.color;
      label = "${r.heartRate}";
    } else if (_selectedMetric == 'O2' && r.oxygen > 0) {
      percentage = (r.oxygen - 80) / 20;
      final eval = VitalValidator.evaluateSpO2(r.oxygen);
      color = eval.color;
      label = "${r.oxygen}";
    } else if (_selectedMetric == 'TEMP' && r.temperature > 0) {
      percentage = (r.temperature - 35) / 5;
      final eval = VitalValidator.evaluateTemp(r.temperature);
      color = eval.color;
      label = "${r.temperature.toInt()}";
    }

    percentage = percentage.clamp(0.05, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (label.isNotEmpty)
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: 16,
          height: 80 * percentage,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text("${r.timestamp.month}/${r.timestamp.day}",
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  // --- 2. DETAILED DIALOG ---
  void _showRecordDetails(VitalSigns data) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Checkup Details",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow("Heart Rate", data.heartRate, "bpm",
                  VitalValidator.evaluateHR(data.heartRate)),
              _buildDetailRow("Blood Pressure", data.systolicBP, "mmHg",
                  VitalValidator.evaluateBP(data.systolicBP, data.diastolicBP),
                  secondary: data.diastolicBP),
              _buildDetailRow("Oxygen (SpO2)", data.oxygen, "%",
                  VitalValidator.evaluateSpO2(data.oxygen)),
              _buildDetailRow("Temperature", data.temperature.toInt(), "°C",
                  VitalValidator.evaluateTemp(data.temperature)),
              if (data.bmi != null)
                _buildDetailRow("BMI", data.bmi!.toInt(), "kg/m²",
                    VitalValidator.evaluateBMI(data.bmi!)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, int value, String unit, VitalEvaluation eval,
      {int? secondary}) {
    bool isSkipped = value == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey))),
          Expanded(
            flex: 3,
            child: isSkipped
                ? const Text("Not Checked",
                    style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                              secondary != null
                                  ? "$value/$secondary"
                                  : "$value",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandDark)),
                          const SizedBox(width: 4),
                          Text(unit,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: eval.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(eval.label,
                            style: TextStyle(
                                color: eval.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 2),
                      Text(eval.advice,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
