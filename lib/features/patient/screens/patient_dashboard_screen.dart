import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../data/mobile_navigation_provider.dart';
import '../../user_history/domain/i_history_repository.dart';
import '../../../core/domain/i_system_repository.dart';
import 'dart:math' as math;

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  bool _isLoading = true;
  List<VitalSigns> _vitals = [];
  String _errorMessage = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool forceSync = true}) async {
    try {
      final authRepo = context.read<IAuthRepository>();
      final historyRepo = context.read<IHistoryRepository>();
      final systemRepo = context.read<ISystemRepository>();
      final user = authRepo.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "User session expired. Please log in again.";
            _isLoading = false;
          });
        }
        return;
      }
      _errorMessage = '';

      // 1. Initial Local Fetch
      await historyRepo.loadUserHistory(user.id);
      
      if (mounted) {
        setState(() {
          _vitals = historyRepo.records;
          _isLoading = false; // SHOW DATA IMMEDIATELY
        });
      }

      // 2. Only sync with Cloud in the background if forced
      if (forceSync) {
        debugPrint("📱 Dashboard: Triggering background cloud sync...");
        // Non-blocking background sync
        systemRepo.syncNow(
          authRepo: authRepo,
          historyRepo: historyRepo,
        ).then((_) {
          if (mounted) {
            setState(() {
              _vitals = historyRepo.records;
            });
          }
        }).catchError((e) {
          debugPrint("⚠️ Dashboard: Background sync error: $e");
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load health records.";
        _isLoading = false;
      });
    }
  }

  List<VitalSigns> _getCleanedVitals() {
    // Filter out records where critical fields are 0 (likely noise/failed sensor reads)
    return _vitals.where((v) {
      final bool hasBP = v.systolicBP > 40 && v.diastolicBP > 30;
      final bool hasHR = v.heartRate > 30;
      final bool hasOxy = v.oxygen > 60;
      return hasBP || hasHR || hasOxy;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<IAuthRepository>().currentUser;
    final systemRepo = context.read<ISystemRepository>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.brandGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 130,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.brandGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7CB335), // brandGreenDark
                        Color(0xFF8CC63F), // brandGreen
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Welcome, ${user?.firstName ?? 'Patient'}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Here's your health overview",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: systemRepo.announcementStream,
                  builder: (context, snapshot) {
                    final hasUpdates = snapshot.hasData && snapshot.data!.isNotEmpty;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded,
                              color: Colors.white, size: 28),
                          onPressed: () {
                            context
                                .read<MobileNavigationProvider>()
                                .goToAnnouncements();
                          },
                        ),
                        if (hasUpdates)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252), // Clinical Red
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                ),
                const SizedBox(width: 8),
              ],
            ),

            // ── Body Content ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(List<Map<String, dynamic>> activeAlerts) {
    if (activeAlerts.isEmpty) return const SizedBox.shrink();

    final latestAlert = activeAlerts.first;
    final bool isEmergency =
        latestAlert['isEmergency'] == 1 || latestAlert['is_emergency'] == true;

    return Container(
      decoration: BoxDecoration(
        color: isEmergency ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmergency
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Show alert detail
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEmergency ? Colors.red : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isEmergency ? Colors.red : Colors.orange)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    isEmergency ? Icons.warning_rounded : Icons.info_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEmergency ? "URGENT SYSTEM ALERT" : "SYSTEM NOTICE",
                        style: TextStyle(
                          color: isEmergency ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestAlert['message'] ?? 'Stay healthy and safe!',
                        style: const TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: (isEmergency ? Colors.red : Colors.orange)
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorRemarksCard() {
    if (_vitals.isEmpty) return const SizedBox.shrink();

    // Find latest record that has remarks
    VitalSigns? recordWithRemarks;
    try {
      recordWithRemarks = _vitals.firstWhere(
        (v) => v.remarks != null && v.remarks!.isNotEmpty,
      );
    } catch (_) {
      recordWithRemarks = _vitals.first;
    }

    if (recordWithRemarks.remarks == null || recordWithRemarks.remarks!.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isVerified = recordWithRemarks.status == 'verified_true' ||
        recordWithRemarks.status == 'verified';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isVerified ? AppColors.brandGreen : Colors.orange,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.rate_review_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  "Health Worker Remarks",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  isVerified ? "Verified" : "Under Review",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recordWithRemarks.remarks!,
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                if (recordWithRemarks.followUpAction != null &&
                    recordWithRemarks.followUpAction != 'none') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medical_services_outlined,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Follow-up: ${_formatAction(recordWithRemarks.followUpAction!)}",
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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
        return "No further action needed at this time.";
    }
  }

  Widget _buildBody() {
    final systemRepo = context.read<ISystemRepository>();
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brandGreen),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Colors.orange, size: 64),
                const SizedBox(height: 16),
                Text(_errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = '';
                    });
                    _loadData();
                  },
                )
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: systemRepo.alertStream,
            builder: (context, snapshot) {
              return _buildAlertBanner(snapshot.data ?? []);
            },
          ),
          const SizedBox(height: 10),
          _buildDoctorRemarksCard(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                  "Barangay Announcement", Icons.campaign_rounded),
              TextButton(
                onPressed: () => context
                    .read<MobileNavigationProvider>()
                    .goToAnnouncements(),
                child: const Text("View All",
                    style: TextStyle(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: systemRepo.announcementStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              final user = context.read<IAuthRepository>().currentUser;
              
              var filtered = list.where((a) {
                final isActive = a['is_active'] == 1 || a['is_active'] == true || a['isActive'] == 1 || a['isActive'] == true;
                final isDeleted = a['is_deleted'] == 1 || a['is_deleted'] == true;
                return isActive && !isDeleted;
              }).toList();

              if (user != null) {
                final int age = user.age;
                filtered = filtered.where((a) {
                  final target = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
                  if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
                  if (target == 'SENIORS' && age >= 60) return true;
                  if (target == 'CHILDREN' && age <= 12) return true;
                  return false;
                }).toList();
              }
              
              return _buildLatestAnnouncementCard(filtered.isEmpty ? null : filtered.first);
            },
          ),
          const SizedBox(height: 24),
          if (_vitals.isEmpty) ...[
            SizedBox(
              height: 350,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9), // AppColors.brandGreenLight equivalent
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monitor_heart_rounded,
                            color: AppColors.brandGreen, size: 56),
                      ),
                      const SizedBox(height: 24),
                      const Text("No Health Records Yet",
                          style: TextStyle(
                              color: AppColors.brandDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          "Visit a Barangay Kiosk to take your first checkup!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey, fontSize: 14, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            _buildSectionHeader(
                "Health Insights", Icons.tips_and_updates_rounded),
            const SizedBox(height: 12),
            _buildInsightsCard(),
            const SizedBox(height: 24),
            _buildLatestMetricsCard(),
            const SizedBox(height: 24),
            _buildTrendsSection(),
            const SizedBox(height: 24),
            _buildSectionHeader("Recent Checkups", Icons.history_rounded),
            const SizedBox(height: 12),
            _buildHistoryList(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    if (_vitals.isEmpty) return const SizedBox.shrink();
    final latest = _vitals.first;

    final List<Map<String, dynamic>> insights = [];

    if (latest.systolicBP > 140 || latest.diastolicBP > 90) {
      insights.add({
        'icon': Icons.warning_amber_rounded,
        'title': 'High Blood Pressure Detected',
        'desc':
            'Consider a restricted sodium diet and consult with your Barangay doctor.',
        'color': Colors.red,
      });
    }
    if (latest.oxygen < 94) {
      insights.add({
        'icon': Icons.air_rounded,
        'title': 'Low Blood Oxygen',
        'desc':
            'Try deep breathing exercises. If you feel short of breath, visit the clinic immediately.',
        'color': Colors.orange,
      });
    }
    if (latest.bmi != null && latest.bmi! > 25) {
      insights.add({
        'icon': Icons.directions_run_rounded,
        'title': 'Weight Management',
        'desc':
            'Your BMI indicates overweight. A regular 30-minute weekly exercise routine is recommended.',
        'color': Colors.blue,
      });
    }

    if (insights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.brandGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.brandGreen, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Looking Good!",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                      "Your latest vitals are within normal limits. Keep up the healthy habits!",
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: insights.map((insight) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (insight['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (insight['color'] as Color).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(insight['icon'] as IconData,
                  color: insight['color'] as Color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight['title'] as String,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: insight['color'] as Color,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(insight['desc'] as String,
                        style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 13,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brandGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.brandDark),
        ),
      ],
    );
  }

  Widget _buildLatestMetricsCard() {
    final latest = _vitals.first;
    final bmiValue = latest.bmi;
    final bmiStr = bmiValue != null ? bmiValue.toStringAsFixed(2) : '--';
    final bmiCategory = _getBmiCategory(bmiValue);

    final date =
        "${latest.timestamp.year}-${latest.timestamp.month.toString().padLeft(2, '0')}-${latest.timestamp.day.toString().padLeft(2, '0')}";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandGreen.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brandGreenDark, AppColors.brandGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text("Latest Checkup",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(date,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),

          // Vitals Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Row 1: BP, Heart, Temp
                Row(
                  children: [
                    Expanded(
                        child: _buildVitalCard(
                            "Blood Pressure",
                            "${latest.systolicBP}/${latest.diastolicBP}",
                            "mmHg",
                            Icons.favorite_rounded,
                            Colors.red.shade400,
                            Colors.red.shade50)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildVitalCard(
                            "Heart Rate",
                            "${latest.heartRate}",
                            "bpm",
                            Icons.monitor_heart_rounded,
                            Colors.purple.shade400,
                            Colors.purple.shade50)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildVitalCard(
                            "Temperature",
                            "${latest.temperature}",
                            "°C",
                            Icons.thermostat_rounded,
                            Colors.orange.shade400,
                            Colors.orange.shade50)),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: SpO2, BMI (wider)
                Row(
                  children: [
                    Expanded(
                        child: _buildVitalCard(
                            "SpO₂",
                            "${latest.oxygen}",
                            "%",
                            Icons.water_drop_rounded,
                            Colors.blue.shade400,
                            Colors.blue.shade50)),
                    const SizedBox(width: 10),
                    Expanded(
                        flex: 2, child: _buildBmiCard(bmiStr, bmiCategory)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(String label, String value, String unit, IconData icon,
      Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      height: 1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Text(unit,
                  style: TextStyle(
                      fontSize: 11, color: iconColor.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: iconColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBmiCard(String bmiStr, String category) {
    final (color, bgColor) = _getBmiColors(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.accessibility_new_rounded, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(bmiStr,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                            height: 1)),
                    const SizedBox(width: 4),
                    Text("BMI",
                        style: TextStyle(
                            fontSize: 11, color: color.withValues(alpha: 0.7))),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(category,
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getBmiCategory(double? bmi) {
    if (bmi == null) return 'N/A';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  (Color, Color) _getBmiColors(String category) {
    switch (category) {
      case 'Underweight':
        return (Colors.blue.shade600, Colors.blue.shade50);
      case 'Normal':
        return (AppColors.brandGreenDark, AppColors.brandGreenLight);
      case 'Overweight':
        return (Colors.orange.shade600, Colors.orange.shade50);
      case 'Obese':
        return (Colors.red.shade600, Colors.red.shade50);
      default:
        return (Colors.grey, Colors.grey.shade100);
    }
  }

  Widget _buildTrendsSection() {
    final cleanedVitals = _getCleanedVitals();
    if (cleanedVitals.isEmpty) return const SizedBox.shrink();

    return DefaultTabController(
      length: 5,
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      color: AppColors.brandGreen, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Health Progress",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${cleanedVitals.length} Checkups",
                      style: const TextStyle(
                        color: AppColors.brandGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: EdgeInsets.symmetric(horizontal: 16),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AppColors.brandGreen,
              indicatorWeight: 3,
              labelColor: AppColors.brandGreen,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: "Blood Pressure"),
                Tab(text: "Heart Rate"),
                Tab(text: "Oxygen"),
                Tab(text: "Temperature"),
                Tab(text: "BMI"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBpTrend(cleanedVitals),
                  _buildHeartRateTrend(cleanedVitals),
                  _buildSpo2Trend(cleanedVitals),
                  _buildTempTrend(cleanedVitals),
                  _buildBmiTrend(cleanedVitals),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart({
    required List<VitalSigns> chartData,
    required List<LineChartBarData> lineBarsData,
    required List<Map<String, dynamic>> legend,
    double? minY,
    double? maxY,
  }) {
    if (chartData.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, color: Colors.grey.shade300, size: 48),
            const SizedBox(height: 8),
            const Text("More data needed for trend.",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: legend
                .map((item) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _buildLegendDot(item['color'], item['label']),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 9),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= chartData.length) {
                          return const SizedBox.shrink();
                        }
                        // Only show every few labels if data is dense
                        if (chartData.length > 7 && index % (chartData.length ~/ 4) != 0 && index != chartData.length-1) {
                          return const SizedBox.shrink();
                        }

                        final date = chartData[index].timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("${date.month}/${date.day}",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 9)),
                        );
                      },
                      interval: 1,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBarsData,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final label = legend[spot.barIndex]['label'];
                        return LineTooltipItem(
                          "${spot.y.toStringAsFixed(0)} $label",
                          TextStyle(
                              color: legend[spot.barIndex]['color'],
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpTrend(List<VitalSigns> cleanedVitals) {
    final chartData = cleanedVitals.reversed.where((v) => v.systolicBP > 0).toList();
    if (chartData.isEmpty) return const SizedBox.shrink();

    double minY = (chartData.map((e) => e.diastolicBP.toDouble()).reduce(math.min) / 10).floor() * 10 - 20;
    double maxY = (chartData.map((e) => e.systolicBP.toDouble()).reduce(math.max) / 10).ceil() * 10 + 20;

    return _buildTrendChart(
      chartData: chartData,
      minY: minY < 0 ? 0 : minY,
      maxY: maxY,
      legend: [
        {'color': Colors.redAccent, 'label': 'Systolic'},
        {'color': Colors.blueAccent, 'label': 'Diastolic'},
      ],
      lineBarsData: [
        _createLineData(
            chartData
                .asMap()
                .entries
                .map((e) =>
                    FlSpot(e.key.toDouble(), e.value.systolicBP.toDouble()))
                .toList(),
            Colors.redAccent),
        _createLineData(
            chartData
                .asMap()
                .entries
                .map((e) =>
                    FlSpot(e.key.toDouble(), e.value.diastolicBP.toDouble()))
                .toList(),
            Colors.blueAccent),
      ],
    );
  }

  Widget _buildHeartRateTrend(List<VitalSigns> cleanedVitals) {
    final chartData = cleanedVitals.reversed.where((v) => v.heartRate > 0).toList();
    return _buildTrendChart(
      chartData: chartData,
      legend: [
        {'color': Colors.purple.shade400, 'label': 'BPM'}
      ],
      lineBarsData: [
        _createLineData(
            chartData
                .asMap()
                .entries
                .map((e) =>
                    FlSpot(e.key.toDouble(), e.value.heartRate.toDouble()))
                .toList(),
            Colors.purple.shade400),
      ],
    );
  }

  Widget _buildSpo2Trend(List<VitalSigns> cleanedVitals) {
    final chartData = cleanedVitals.reversed.where((v) => v.oxygen > 0).toList();
    return _buildTrendChart(
      chartData: chartData,
      maxY: 105,
      minY: (chartData.isEmpty) ? 80 : (chartData.map((e) => e.oxygen.toDouble()).reduce(math.min) - 5),
      legend: [
        {'color': Colors.blue.shade400, 'label': '%'}
      ],
      lineBarsData: [
        _createLineData(
            chartData
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.oxygen.toDouble()))
                .toList(),
            Colors.blue.shade400),
      ],
    );
  }

  Widget _buildTempTrend(List<VitalSigns> cleanedVitals) {
    final chartData = cleanedVitals.reversed.where((v) => v.temperature > 0).toList();
    if (chartData.isEmpty) return const SizedBox.shrink();

    return _buildTrendChart(
      chartData: chartData,
      legend: [
        {'color': Colors.orange.shade400, 'label': '°C'}
      ],
      lineBarsData: [
        _createLineData(
            chartData
                .asMap()
                .entries
                .map((e) =>
                    FlSpot(e.key.toDouble(), e.value.temperature.toDouble()))
                .toList(),
            Colors.orange.shade400),
      ],
    );
  }

  Widget _buildBmiTrend(List<VitalSigns> cleanedVitals) {
    final chartData = cleanedVitals.reversed
        .where((v) => v.bmi != null && v.bmi! > 0)
        .toList();
    if (chartData.isEmpty) return const SizedBox.shrink();

    return _buildTrendChart(
      chartData: chartData,
      legend: [
        {'color': Colors.teal.shade400, 'label': 'BMI'}
      ],
      lineBarsData: [
        _createLineData(
            chartData
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.bmi!.toDouble()))
                .toList(),
            Colors.teal.shade400),
      ],
    );
  }

  Widget _buildLatestAnnouncementCard(Map<String, dynamic>? latestAnnouncement) {
    if (latestAnnouncement == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.brandGreen, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're all caught up!",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.brandDark)),
                  SizedBox(height: 4),
                  Text(
                      "There are no active announcements from the Barangay at the moment.",
                      style: TextStyle(
                          color: Colors.grey, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final title = latestAnnouncement['title'] ?? 'Announcement';
    final content = latestAnnouncement['content'] ?? '';
    final isUrgent = latestAnnouncement['target_group'] == 'BROADCAST_ALL';

    return GestureDetector(
      onTap: () {
        context.read<MobileNavigationProvider>().goToAnnouncements();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [Colors.red.shade700, Colors.red.shade500]
                : [AppColors.brandGreenDark, AppColors.brandGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.red : AppColors.brandGreen)
                  .withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUrgent
                        ? Icons.warning_rounded
                        : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white70, size: 14),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _createLineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: color),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHistoryList() {
    final recent = _vitals.take(5).toList();
    return Column(
      children: recent.asMap().entries.map((entry) {
        final vital = entry.value;
        final isHypertensive = vital.systolicBP > 140;
        final date =
            "${vital.timestamp.year}-${vital.timestamp.month.toString().padLeft(2, '0')}-${vital.timestamp.day.toString().padLeft(2, '0')}";
        final bmiStr = vital.bmi != null ? vital.bmi!.toStringAsFixed(2) : '--';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHypertensive ? Colors.red.shade200 : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isHypertensive
                    ? Colors.red.shade50
                    : const Color(0xFFE8F5E9), // AppColors.brandGreenLight equivalent
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHypertensive
                    ? Icons.warning_amber_rounded
                    : Icons.monitor_heart_rounded,
                color: isHypertensive ? Colors.red : AppColors.brandGreen,
                size: 22,
              ),
            ),
            title: Text(date,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark,
                    fontSize: 14)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                children: [
                  _buildChip("BP: ${vital.systolicBP}/${vital.diastolicBP}",
                      isHypertensive ? Colors.red : Colors.grey.shade600),
                  _buildChip("HR: ${vital.heartRate} bpm", Colors.grey.shade600),
                  _buildChip("BMI $bmiStr", Colors.grey.shade600),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
            onTap: () {
              context
                  .read<MobileNavigationProvider>()
                  .setIndex(1); // Go to History Tab
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Text(label, style: TextStyle(fontSize: 12, color: color));
  }
}
