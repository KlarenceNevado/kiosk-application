import 'package:flutter/material.dart';
import '../../admin/data/admin_repository.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../../../core/services/system/sync_event_bus.dart';
import '../../user_history/domain/i_history_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../../auth/domain/i_auth_repository.dart';
import 'mobile_history_screen.dart';
import 'mobile_login_screen.dart';
import '../../../../core/widgets/alert_banner.dart';
import 'dart:async';

class MobileDashboardScreen extends StatefulWidget {
  final String userId; // Mock User ID
  final String userName;

  const MobileDashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  // Live Data from Supabase
  VitalSigns? _latestRecord;
  bool _isLoading = true;
  StreamSubscription? _alertSub;
  Map<String, dynamic>? _activeAlert;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToAlerts();
  }

  void _subscribeToAlerts() {
    _alertSub = SyncEventBus.instance.newAlertStream.listen((alert) {
      if (mounted) {
        final target = alert['target_group']?.toString().toUpperCase() ?? 'ALL';
        if (target == 'ALL' ||
            target == 'BROADCAST_ALL' ||
            target == 'PATIENTS') {
          setState(() => _activeAlert = alert);
        }
      }
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final historyRepo = context.read<IHistoryRepository>();
      await historyRepo.loadUserHistory(widget.userId);
      final records = historyRepo.records;
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (records.isNotEmpty) {
            _latestRecord = records.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading latest vital sign: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await context.read<IAuthRepository>().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      appBar: AppBar(
        title: Text("Patient Dashboard", style: AppTextStyles.labelMedium),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.brandDark),
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_activeAlert != null)
              AlertBanner(
                message: _activeAlert!['message'] ?? '',
                targetGroup: _activeAlert!['target_group'] ?? 'ALL',
                isEmergency: _activeAlert!['is_emergency'] == true ||
                    _activeAlert!['is_emergency'] == 1,
                onDismiss: () => setState(() => _activeAlert = null),
              ),

            // --- HEADER HERO CARD ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.brandGreenLight,
                        child: Text(
                          widget.userName.isNotEmpty
                              ? widget.userName[0].toUpperCase()
                              : "?",
                          style: const TextStyle(
                              color: AppColors.brandGreenDark,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Welcome back,",
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16)),
                            Text(
                              widget.userName,
                              style: AppTextStyles.h1
                                  .copyWith(fontSize: 24, letterSpacing: -0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- COMPANION APP INFO BANNER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Companion App",
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          SizedBox(height: 6),
                          Text(
                            "This portal is for viewing past records. To take new vital sign readings, please visit and use the physical Barangay Health Kiosk hardware.",
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- UPCOMING EVENTS (SCHEDULES) ---
            _buildUpcomingEvents(context),

            const SizedBox(height: 24),

            // --- VITALS OVERVIEW ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Latest Stats",
                          style: AppTextStyles.h1.copyWith(fontSize: 20)),
                      const Text("Today",
                          style: TextStyle(
                              color: AppColors.brandGreenDark,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(
                            color: AppColors.brandGreen),
                      ),
                    )
                  else if (_latestRecord == null)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Text("No records found.",
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    )
                  else
                    _buildVitalsCard(_latestRecord!),

                  const SizedBox(height: 32),

                  // --- ACTION BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FlowAnimatedButton(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MobileHistoryScreen()));
                        },
                        icon: const Icon(Icons.history_rounded, size: 24),
                        label: const Text("View Full History",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                                color: AppColors.brandGreen, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEvents(BuildContext context) {
    final adminRepo = context.watch<AdminRepository>();
    final schedules = adminRepo.schedules;

    if (schedules.isEmpty) return const SizedBox.shrink();

    // Filter for future events only
    final upcoming = schedules
        .where((s) =>
            s.date.isAfter(DateTime.now().subtract(const Duration(hours: 4))))
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Upcoming Events",
                  style: AppTextStyles.h1.copyWith(fontSize: 20)),
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.brandGreenDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final event = upcoming[index];
              final daysLeft = event.date.difference(DateTime.now()).inDays;

              return Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandDark,
                      AppColors.brandDark.withValues(alpha: 0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandDark.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            daysLeft == 0
                                ? "TODAY"
                                : (daysLeft == 1
                                    ? "TOMORROW"
                                    : "IN $daysLeft DAYS"),
                            style: const TextStyle(
                              color: AppColors.brandGreenLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Icon(Icons.info_outline,
                            color: Colors.white70, size: 18),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      event.type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM dd, yyyy • hh:mm a').format(event.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsCard(VitalSigns record) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ]),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _vitalItem(Icons.favorite_rounded, "Heart Rate",
                        "${record.heartRate}", "bpm", Colors.red)),
                Container(width: 1, height: 60, color: Colors.grey.shade200),
                Expanded(
                    child: _vitalItem(Icons.water_drop_rounded, "Blood Oxygen",
                        "${record.oxygen}", "%", Colors.blue)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Color(0xFFEEEEEE)),
            ),
            Row(
              children: [
                Expanded(
                    child: _vitalItem(
                        Icons.speed_rounded,
                        "Blood Pressure",
                        "${record.systolicBP}/${record.diastolicBP}",
                        "mmHg",
                        Colors.orange)),
                Container(width: 1, height: 60, color: Colors.grey.shade200),
                Expanded(
                    child: _vitalItem(Icons.thermostat_rounded, "Temperature",
                        "${record.temperature}", "°C", Colors.orangeAccent)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Color(0xFFEEEEEE)),
            ),
            _vitalItem(
                Icons.monitor_weight_rounded,
                "BMI",
                record.bmi != null ? record.bmi!.toStringAsFixed(1) : "--",
                record.bmiCategory ?? "N/A",
                Colors.purple)
          ],
        ),
      ),
    );
  }

  Widget _vitalItem(
      IconData icon, String label, String value, String unit, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: AppColors.brandDark,
                    letterSpacing: -0.5)),
            const SizedBox(width: 2),
            Text(unit,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
