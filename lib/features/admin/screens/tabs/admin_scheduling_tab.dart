import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/admin_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';

class AdminSchedulingTab extends StatefulWidget {
  const AdminSchedulingTab({super.key});

  @override
  State<AdminSchedulingTab> createState() => _AdminSchedulingTabState();
}

class _AdminSchedulingTabState extends State<AdminSchedulingTab> {
  final TextEditingController _locationController = TextEditingController();
  String _selectedActivity = 'vaccination';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedAssigned = 'Unassigned';
  bool _autoAnnounce = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminRepo = context.watch<AdminRepository>();
    final authRepo = context.watch<IAuthRepository>();
    final schedules = adminRepo.schedules;

    return Row(children: [
      // Left Pane: Calendar Planner (Upcoming List View)
      Expanded(
          flex: 5,
          child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Calendar Planner",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Expanded(
                        child: ListView.separated(
                            itemCount: schedules.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final sched = schedules[index];
                              return Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.02),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Left colored accent line
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: 6,
                                        child: Container(color: sched.color),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Row(
                                          children: [
                                            // Main Info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(sched.type,
                                                      style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .brandDark)),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.location_on,
                                                          size: 16,
                                                          color: sched.color),
                                                      const SizedBox(width: 8),
                                                      Text(sched.location,
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.group,
                                                          size: 16,
                                                          color: sched.color),
                                                      const SizedBox(width: 8),
                                                      Text(sched.assigned,
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500)),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ),
                                            // Delete Button inside flow
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent),
                                              tooltip: "Cancel Schedule",
                                              onPressed: () {
                                                adminRepo
                                                    .deleteSchedule(sched.id);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      // TOP RIGHT CORNER: Date
                                      Positioned(
                                        top: 16,
                                        right: 24,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: sched.color
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            DateFormat('MMM dd, yyyy')
                                                .format(sched.phtDate),
                                            style: TextStyle(
                                              color: sched.color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // BOTTOM RIGHT CORNER: Time
                                      Positioned(
                                        bottom: 16,
                                        right: 24,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.access_time_filled,
                                                size: 16, color: sched.color),
                                            const SizedBox(width: 6),
                                            Text(
                                              DateFormat('hh:mm a')
                                                  .format(sched.phtDate),
                                              style: TextStyle(
                                                color: sched.color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ));
                            }))
                  ]))),

      // Right Pane: Schedule New Activity
      Expanded(
          flex: 4,
          child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Schedule New Activity",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandDark)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Activity Type",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedActivity,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'vaccination',
                                        child: Text("Vaccination Drive")),
                                    DropdownMenuItem(
                                        value: 'home_visit',
                                        child: Text(
                                            "Household Inspection / Visit")),
                                    DropdownMenuItem(
                                        value: 'meeting',
                                        child: Text("BHW Meeting")),
                                    DropdownMenuItem(
                                        value: 'clinic',
                                        child: Text("Barangay Clinic Day")),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _selectedActivity = val!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text("Date",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16, horizontal: 16),
                                          alignment: Alignment.centerLeft),
                                      icon: const Icon(Icons.calendar_month),
                                      label: Text(DateFormat('MMM dd, yyyy')
                                          .format(_selectedDate)),
                                      onPressed: () async {
                                        final date = await showDatePicker(
                                            context: context,
                                            initialDate: _selectedDate,
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime(2030));
                                        if (date != null) {
                                          setState(() => _selectedDate = date);
                                        }
                                      },
                                    )
                                  ])),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text("Time",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16, horizontal: 16),
                                          alignment: Alignment.centerLeft),
                                      icon: const Icon(Icons.access_time),
                                      label:
                                          Text(_selectedTime.format(context)),
                                      onPressed: () async {
                                        final time = await showTimePicker(
                                            context: context,
                                            initialTime: _selectedTime);
                                        if (time != null) {
                                          setState(() => _selectedTime = time);
                                        }
                                      },
                                    )
                                  ])),
                            ]),
                            const SizedBox(height: 24),
                            const Text("Location",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                hintText: "Enter location details...",
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text("Assigned BHW",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedAssigned,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'Unassigned',
                                        child: Text("Unassigned")),
                                    ...authRepo.users.map((u) =>
                                        DropdownMenuItem(
                                            value: u.fullName,
                                            child: Text(u.fullName))),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _selectedAssigned = val!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SwitchListTile(
                              title: const Text("Share with Community",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.brandDark)),
                              subtitle: const Text(
                                  "Automatically announce this schedule in Patient Mobile Inbox",
                                  style: TextStyle(fontSize: 12)),
                              activeThumbColor: AppColors.brandGreen,
                              value: _autoAnnounce,
                              onChanged: (val) =>
                                  setState(() => _autoAnnounce = val),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text("SAVE SCHEDULE",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandGreen),
                            onPressed: () async {
                              if (_locationController.text.isEmpty) return;

                              final adminRepo = context.read<AdminRepository>();

                              await adminRepo.addSchedule(
                                type: _selectedActivity
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                date: DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    _selectedTime.hour,
                                    _selectedTime.minute),
                                location: _locationController.text,
                                assigned: _selectedAssigned,
                                color: AppColors.brandDark,
                              );

                              if (!context.mounted) return;

                              if (_autoAnnounce) {
                                final format = DateFormat('MMM dd, yyyy')
                                    .format(_selectedDate);
                                final timeFmt = _selectedTime.format(context);
                                await adminRepo.addAnnouncement(
                                  title:
                                      "Upcoming ${_selectedActivity.replaceAll('_', ' ').toUpperCase()}",
                                  content:
                                      "There will be a ${_selectedActivity.replaceAll('_', ' ')} on $format at $timeFmt. Location: ${_locationController.text}. BHW in charge: $_selectedAssigned.",
                                  targetGroup: 'all',
                                );
                              }

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text("Schedule successfully created!"),
                                backgroundColor: AppColors.brandGreen,
                              ));
                              _locationController.clear();
                              setState(() {
                                _autoAnnounce = false;
                              });
                            }))
                  ])))
    ]);
  }
}
