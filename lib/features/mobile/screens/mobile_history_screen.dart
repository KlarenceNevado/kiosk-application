import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/database/sync_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../services/patient_pdf_service.dart';

class MobileHistoryScreen extends StatefulWidget {
  const MobileHistoryScreen({super.key});

  @override
  State<MobileHistoryScreen> createState() => _MobileHistoryScreenState();
}

class _MobileHistoryScreenState extends State<MobileHistoryScreen> {
  // Live data from Supabase
  final List<VitalSigns> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final user = context.read<AuthRepository>().currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final records = await SyncService().fetchPatientVitals(user.id);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _records.clear();
          _records.addAll(records);
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      appBar: AppBar(
        title: Text("Health History", style: AppTextStyles.labelMedium),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.brandDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen))
          : _records.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 16, bottom: 40, left: 16, right: 16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final date = record.timestamp;

                    return GestureDetector(
                      onTap: () async {
                        final authRepo =
                            Provider.of<AuthRepository>(context, listen: false);
                        final currentUser = authRepo.currentUser;
                        if (currentUser != null) {
                          await PatientPdfService.generateAndPrintRecord(
                            patient: currentUser,
                            record: record,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // DATE HEADER
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandGreenLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.calendar_month_rounded,
                                        color: AppColors.brandGreenDark,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      DateFormat('MMMM dd, yyyy').format(date),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.brandDark),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('hh:mm a').format(date),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                              ),

                              // METRICS ROW 1
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _metricBadge(Icons.favorite_rounded, "Pulse",
                                      "${record.heartRate} bpm", Colors.red),
                                  _metricBadge(Icons.water_drop_rounded, "SpO2",
                                      "${record.oxygen}%", Colors.blue),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // METRICS ROW 2
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _metricBadge(
                                      Icons.speed_rounded,
                                      "BP",
                                      "${record.systolicBP}/${record.diastolicBP}",
                                      Colors.orange),
                                  _metricBadge(
                                      Icons.thermostat_rounded,
                                      "Temp",
                                      "${record.temperature} °C",
                                      Colors.orangeAccent),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // METRICS ROW 3
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _metricBadge(
                                      Icons.monitor_weight_rounded,
                                      "BMI",
                                      record.bmi != null
                                          ? "${record.bmi!.toStringAsFixed(1)} (${record.bmiCategory ?? 'N/A'})"
                                          : "N/A",
                                      Colors.purple),
                                  const Expanded(child: SizedBox.shrink()),
                                ],
                              ),

                              // BHW REMARKS SECTION
                              if (record.remarks != null &&
                                  record.remarks!.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                      height: 1, color: Color(0xFFEEEEEE)),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandGreen
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: AppColors.brandGreen
                                            .withValues(alpha: 0.1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.note_alt_rounded,
                                              size: 18,
                                              color: AppColors.brandGreen),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "BHW Remarks",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.brandGreenDark,
                                            ),
                                          ),
                                          const Spacer(),
                                          _buildStatusBadge(record.status),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        record.remarks!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.brandDark,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (record.followUpAction != null &&
                                          record.followUpAction != 'none') ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.info_outline,
                                                  size: 14,
                                                  color: Colors.orange),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Action: ${_formatAction(record.followUpAction!)}",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = "Pending";

    if (status == 'verified_true') {
      color = AppColors.brandGreen;
      label = "Verified";
    } else if (status == 'verified_false') {
      color = Colors.red;
      label = "Anomaly";
    } else if (status == 'requires_retest') {
      color = Colors.orange;
      label = "Re-test";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _formatAction(String action) {
    switch (action) {
      case 'advise_clinic':
        return "Advise Clinic Visit";
      case 'home_visit':
        return "Schedule Home Visit";
      case 'refer_municipal':
        return "Refer to Municipal Office";
      default:
        return "No Action Needed";
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                    )
                  ]),
              child: const Icon(Icons.history_rounded,
                  size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              "No History Found",
              style: AppTextStyles.h1.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Your health check records will appear here once you take a test at the kiosk.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
            ],
          ),
        ],
      ),
    );
  }
}
