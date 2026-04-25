import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/routes.dart';
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
  final TextEditingController _noteController = TextEditingController();
  String _selectedActivity = 'vaccination';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedAssigned = 'Unassigned';
  bool _autoAnnounce = false;

  final List<Map<String, dynamic>> _activityTypes = [
    {'id': 'vaccination', 'label': 'Vaccination Drive', 'color': Colors.blue},
    {'id': 'home_visit', 'label': 'Household Inspection / Visit', 'color': Colors.orange},
    {'id': 'clinic', 'label': 'Barangay Clinic Day', 'color': Colors.green},
    {'id': 'meeting', 'label': 'BHW Staff Meeting', 'color': Colors.blueGrey},
    {'id': 'senior_wellness', 'label': 'Senior Citizen Wellness', 'color': Colors.purple},
    {'id': 'maternal_health', 'label': 'Maternal Health / Pre-natal', 'color': Colors.pink},
    {'id': 'nutrition', 'label': 'Nutrition & Feeding Program', 'color': Colors.teal},
    {'id': 'dental', 'label': 'Dental Check-up', 'color': Colors.cyan},
    {'id': 'emergency_drill', 'label': 'Health Emergency Drill', 'color': Colors.red},
    {'id': 'mental_health', 'label': 'Mental Health Awareness', 'color': Colors.indigo},
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminRepo = context.watch<AdminRepository>();
    final authRepo = context.watch<IAuthRepository>();
    final schedules = adminRepo.schedules;

    // Correctly filter for staff members only
    final staffMembers = authRepo.users
        .where((u) => u.role.toLowerCase() == 'admin' || u.role.toLowerCase() == 'bhw')
        .toList();

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Calendar Planner",
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${schedules.length} Scheduled Events",
                            style: const TextStyle(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                        child: schedules.isEmpty 
                        ? _buildEmptySchedules()
                        : ListView.separated(
                            itemCount: schedules.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final sched = schedules[index];
                              return _buildScheduleCard(sched, adminRepo);
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
                            const Text("Activity Category",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 12)),
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
                                  items: _activityTypes.map((type) => DropdownMenuItem(
                                    value: type['id'] as String,
                                    child: Row(
                                      children: [
                                        Icon(Icons.circle, color: type['color'] as Color, size: 12),
                                        const SizedBox(width: 12),
                                        Text(type['label'] as String),
                                      ],
                                    ),
                                  )).toList(),
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
                                            color: Colors.grey,
                                            fontSize: 12)),
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
                                      icon: const Icon(Icons.calendar_month, color: AppColors.brandGreen),
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
                                            color: Colors.grey,
                                            fontSize: 12)),
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
                                      icon: const Icon(Icons.access_time, color: AppColors.brandGreen),
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
                                    color: Colors.grey,
                                    fontSize: 12)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                hintText: "e.g. Barangay Hall, Purok 4",
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text("Assigned Health Worker",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 12)),
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
                                  hint: const Text("Select Staff Member"),
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'Unassigned',
                                        child: Text("Unassigned")),
                                    ...staffMembers.map((u) =>
                                        DropdownMenuItem(
                                            value: u.fullName,
                                            child: Row(
                                              children: [
                                                Icon(Icons.person_outline, size: 16, color: u.role == 'admin' ? Colors.red : Colors.blue),
                                                const SizedBox(width: 12),
                                                Text("${u.fullName} (${u.role.toUpperCase()})"),
                                              ],
                                            ))),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _selectedAssigned = val!),
                                ),
                              ),
                            ),
                            if (staffMembers.isEmpty) 
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("⚠️ No BHW/Admin accounts found to assign.", 
                                      style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    TextButton.icon(
                                      onPressed: () => context.push(AppRoutes.adminUsers),
                                      icon: const Icon(Icons.people_outline, size: 14),
                                      label: const Text("Go to User Directory to promote staff", style: TextStyle(fontSize: 11)),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: SwitchListTile(
                                title: const Text("Share with Community",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.brandDark)),
                                subtitle: const Text(
                                    "Automatically announce this schedule in Resident Mobile Inbox",
                                    style: TextStyle(fontSize: 12)),
                                activeThumbColor: AppColors.brandGreen,
                                value: _autoAnnounce,
                                onChanged: (val) =>
                                    setState(() => _autoAnnounce = val),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined, color: Colors.white),
                            label: const Text("SAVE SCHEDULE",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () async {
                              if (_locationController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text("Please enter a location."),
                                  backgroundColor: Colors.orange,
                                ));
                                return;
                              }

                              final adminRepo = context.read<AdminRepository>();
                              final activityLabel = _activityTypes.firstWhere((t) => t['id'] == _selectedActivity)['label'] as String;
                              final activityColor = _activityTypes.firstWhere((t) => t['id'] == _selectedActivity)['color'] as Color;

                              await adminRepo.addSchedule(
                                type: activityLabel,
                                date: DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    _selectedTime.hour,
                                    _selectedTime.minute),
                                location: _locationController.text,
                                assigned: _selectedAssigned,
                                color: activityColor,
                              );

                              if (!context.mounted) return;

                              if (_autoAnnounce) {
                                final format = DateFormat('MMM dd, yyyy')
                                    .format(_selectedDate);
                                final timeFmt = _selectedTime.format(context);
                                await adminRepo.addAnnouncement(
                                  title: "Upcoming $activityLabel",
                                  content:
                                      "Attention Residents! There will be a $activityLabel on $format at $timeFmt. Location: ${_locationController.text}. Health worker in charge: $_selectedAssigned. Please attend if applicable.",
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

  Widget _buildScheduleCard(dynamic sched, AdminRepository adminRepo) {
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person_pin,
                                size: 16,
                                color: sched.color),
                            const SizedBox(width: 8),
                            Text("Assigned: ${sched.assigned}",
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500)),
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
                    onPressed: () => _confirmDelete(context, sched, adminRepo),
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
  }

  Widget _buildEmptySchedules() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[100]),
          const SizedBox(height: 16),
          const Text("No Upcoming Activities", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Use the form on the right to schedule a health event.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic sched, AdminRepository repo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Activity?"),
        content: Text("Are you sure you want to remove the '${sched.type}' schedule? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
          TextButton(
            onPressed: () {
              repo.deleteSchedule(sched.id);
              Navigator.pop(context);
            }, 
            child: const Text("YES, REMOVE", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
