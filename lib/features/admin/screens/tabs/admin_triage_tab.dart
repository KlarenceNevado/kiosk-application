import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../user_history/domain/i_history_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../../health_check/models/vital_signs_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../chat/domain/i_chat_repository.dart';
import '../../../chat/models/chat_message.dart';
import '../../data/admin_repository.dart';
import '../../../../core/utils/health_thresholds.dart';

class AdminTriageTab extends StatelessWidget {
  const AdminTriageTab({super.key});

  bool _isCritical(VitalSigns record, User user) {
    return HealthThresholds.isCritical(user, record);
  }

  String _getCriticalReason(VitalSigns record, User user) {
    List<String> reasons = HealthThresholds.evaluate(user, record);
    return reasons.join(", ");
  }

  String _getAiAdvice(VitalSigns record, User user) {
    List<String> reasons = HealthThresholds.evaluate(user, record);
    String advice = "";
    
    if (reasons.any((r) => r.contains("BP"))) {
      advice += "⚠️ MATAAS/MABABA ang Blood Pressure. Ito ay delikado para sa edad na ${user.age} dahil maari itong magdulot ng stroke o heart attack. ";
    }
    if (reasons.any((r) => r.contains("O2"))) {
      advice += "💨 Ang oxygen level ay MABABA. Maaring nahihirapan huminga ang resident. ";
    }
    if (reasons.any((r) => r.contains("Fever"))) {
      advice += "🌡️ May LAGNAT. Kailangan ng pahinga at sapat na tubig. ";
    }
    if (reasons.any((r) => r.contains("Heart Rate"))) {
      advice += "💓 Masyadong MABILIS/MABAGAL ang tibok ng puso. ";
    }
    
    if (advice.isEmpty && reasons.any((r) => r.contains("Obesity"))) {
      advice = "⚖️ Ang BMI ay Obese. Kailangan ng lifestyle changes para maiwasan ang sakit sa puso at diabetes.";
    }

    return advice.isNotEmpty ? advice : "Ang mga vitals ay nangangailangan ng monitoring ng BHW.";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<IHistoryRepository, IAuthRepository, AdminRepository>(
      builder: (context, historyRepo, authRepo, adminRepo, child) {
        final triageRecords = historyRepo.records
            .where((r) {
              final users = authRepo.users.where((u) => u.id == r.userId);
              if (users.isEmpty) return false;
              return _isCritical(r, users.first);
            })
            .toList();

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(32),
              color: Colors.white,
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Triage: Immediate Attention",
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandDark)),
                      SizedBox(height: 4),
                      Text("Active cases with anomalous vital signs requiring BHW intervention.",
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: triageRecords.isEmpty ? AppColors.brandGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(triageRecords.isEmpty ? Icons.check_circle : Icons.warning, 
                             color: triageRecords.isEmpty ? AppColors.brandGreen : Colors.red),
                        const SizedBox(width: 12),
                        Text(
                          triageRecords.isEmpty ? "All Clear" : "${triageRecords.length} Cases Pending",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: triageRecords.isEmpty ? AppColors.brandGreen : Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: triageRecords.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(32),
                      itemCount: triageRecords.length,
                      itemBuilder: (context, index) {
                        final record = triageRecords[index];
                        final user = authRepo.users.firstWhere(
                          (u) => u.id == record.userId,
                          orElse: () => User(
                              id: '',
                              firstName: 'Unknown',
                              middleInitial: '',
                              lastName: 'User',
                              sitio: 'Unknown Sitio',
                              phoneNumber: 'N/A',
                              pinCode: '',
                              dateOfBirth: DateTime.now(),
                              gender: 'N/A',
                              username: 'unknown'),
                        );

                        return _buildTriageCard(context, record, user);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          const Text("No critical cases detected",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Great! All recent readings are within normal thresholds.",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTriageCard(BuildContext context, VitalSigns record, User user) {
    final reason = _getCriticalReason(record, user);

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade100, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Resident Info
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("RESIDENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("Sitio: ${user.sitio} • Phone: ${user.phoneNumber}", style: const TextStyle(color: Colors.grey)),
                    const Spacer(),
                    Text(DateFormat('MMMM dd, hh:mm a').format(record.phtTimestamp), 
                         style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ],
                ),
              ),

              const VerticalDivider(width: 48),

              // Vitals & Reason
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ANOMALY DETECTED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade400, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text(reason, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        _buildVitalChip("BP: ${record.systolicBP}/${record.diastolicBP}"),
                        _buildVitalChip("HR: ${record.heartRate}"),
                        _buildVitalChip("SpO2: ${record.oxygen}%"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getAiAdvice(record, user),
                              style: TextStyle(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const VerticalDivider(width: 48),

              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _notifyResident(context, user, record),
                    icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                    label: const Text("NOTIFY RESIDENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandDark,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      // Navigate to validation with this record selected
                      // For now just mark as reviewed locally? 
                      // Better to just show validation tab logic here
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("View Full Report"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  void _notifyResident(BuildContext context, User user, VitalSigns record) {
    final chatRepo = context.read<IChatRepository>();
    
    // 1. Create the alert message
    final messageText = "⚠️ HEALTH ALERT: Magandang araw ${user.firstName}. Napansin po namin sa inyong huling reading (BP: ${record.systolicBP}/${record.diastolicBP}) na nangangailangan po kayo ng pansin. Mangyari lamang po na mag-pahinga at pumunta sa pinakamalapit na Health Center kung kayo ay nakakaramdam ng pagkahilo o pananakit ng batok.";
    
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: 'admin',
      receiverId: user.id,
      content: messageText,
      timestamp: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 2. Send via Repository
    chatRepo.sendMessage(message);

    // 3. Provide feedback
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Notification sent to ${user.fullName} via Chat."),
      backgroundColor: AppColors.brandDark,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
