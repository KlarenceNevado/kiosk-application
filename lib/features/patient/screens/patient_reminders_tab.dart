import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/security/notification_service.dart';

class PatientRemindersTab extends StatefulWidget {
  const PatientRemindersTab({super.key});

  @override
  State<PatientRemindersTab> createState() => _PatientRemindersTabState();
}

class _PatientRemindersTabState extends State<PatientRemindersTab> {
  final List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    // In a prod app, these would load from local SQLite storage linked to the user account
  }

  void _showAddReminderSheet() {
    final titleCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("New Pill Reminder",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Medication Name (e.g. Losartan)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300)),
                    title: const Text("Time"),
                    trailing: Text(selectedTime.format(context),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandGreen)),
                    onTap: () async {
                      final time = await showTimePicker(
                          context: context, initialTime: selectedTime);
                      if (time != null) {
                        setModalState(() => selectedTime = time);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.isNotEmpty) {
                          // Standardize an ID based on list length
                          final reminderId = _reminders.length + 1;

                          await NotificationService()
                              .scheduleDailyMedicationReminder(
                            id: reminderId,
                            medicationName: titleCtrl.text,
                            time: selectedTime,
                          );

                          setState(() {
                            _reminders.add({
                              'id': reminderId,
                              'title': titleCtrl.text,
                              'time': selectedTime,
                              'isActive': true,
                            });
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Set Alarm",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Reminders",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandGreen,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminderSheet,
        backgroundColor: AppColors.brandGreen,
        icon: const Icon(Icons.alarm_add_rounded, color: Colors.white),
        label: const Text("Add Pill",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _reminders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_off_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("No reminders yet",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text("Never forget your medication again.",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final r = _reminders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.medication_rounded,
                          color: AppColors.brandGreen),
                    ),
                    title: Text(r['title'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text((r['time'] as TimeOfDay).format(context),
                        style: const TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w600)),
                    trailing: Switch(
                      value: r['isActive'],
                      activeThumbColor: AppColors.brandGreen,
                      onChanged: (val) {
                        setState(() => r['isActive'] = val);
                        if (!val) {
                          NotificationService()
                              .flutterLocalNotificationsPlugin
                              .cancel(r['id']);
                        } else {
                          // Re-schedule
                          NotificationService().scheduleDailyMedicationReminder(
                            id: r['id'],
                            medicationName: r['title'],
                            time: r['time'],
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
