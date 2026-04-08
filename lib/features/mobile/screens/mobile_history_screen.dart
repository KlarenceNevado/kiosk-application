import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../user_history/domain/i_history_repository.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistory();
    });
  }

  Future<void> _fetchHistory() async {
    try {
      final authRepo = context.read<IAuthRepository>();
      final user = authRepo.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final historyRepo = context.read<IHistoryRepository>();
      await historyRepo.loadUserHistory(user.id);
      final records = historyRepo.records;

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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.brandDark),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen))
          : _records.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  color: AppColors.brandGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                        top: 16, bottom: 40, left: 16, right: 16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _buildHistoryCard(record);
                    },
                  ),
                ),
    );
  }

  Widget _buildHistoryCard(VitalSigns record) {
    final date = record.timestamp;
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(date);
    final recordId = record.id.substring(0, 8).toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date & ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                          fontSize: 13, color: Colors.blueGrey.shade400),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.brandGreen.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    "ID: $recordId",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandGreen,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),

            // Metrics Grid
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                _clinicalMetric(
                  "Pulse Rate",
                  record.heartRate > 0 ? "${record.heartRate}" : "--",
                  "bpm",
                  CupertinoIcons.heart_fill,
                  Colors.red.shade600,
                ),
                _clinicalMetric(
                  "Oxygen",
                  record.oxygen > 0 ? "${record.oxygen}" : "--",
                  "%",
                  CupertinoIcons.wind,
                  Colors.blue.shade600,
                ),
                _clinicalMetric(
                  "Blood Pressure",
                  (record.systolicBP > 0 && record.diastolicBP > 0)
                      ? "${record.systolicBP}/${record.diastolicBP}"
                      : "--",
                  "mmHg",
                  CupertinoIcons.gauge,
                  Colors.orange.shade700,
                ),
                _clinicalMetric(
                  "Temperature",
                  record.temperature > 0 ? "${record.temperature}" : "--",
                  "°C",
                  CupertinoIcons.thermometer,
                  Colors.amber.shade800,
                ),
              ],
            ),

            if (record.remarks != null && record.remarks!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.chat_bubble_text_fill,
                            size: 14, color: Colors.blueGrey.shade400),
                        const SizedBox(width: 8),
                        const Text(
                          "MEDICAL REMARKS",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B)),
                        ),
                        const Spacer(),
                        _buildStatusBadge(record.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      record.remarks!,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authRepo =
                      Provider.of<IAuthRepository>(context, listen: false);
                  await PatientPdfService.generateAndPrintRecord(
                    patient: authRepo.currentUser!,
                    record: record,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text("ACCESS CLINICAL PDF"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandGreen,
                  side: BorderSide(
                      color: AppColors.brandGreen.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clinicalMetric(
      String label, String value, String unit, IconData icon, Color color) {
    return SizedBox(
      width: 145,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade300,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blueGrey.shade300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
}
