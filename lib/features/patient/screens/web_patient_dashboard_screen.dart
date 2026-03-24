import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../auth/data/web_auth_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../data/mobile_navigation_provider.dart';

/// Web-safe Patient Dashboard. Uses Supabase directly. No SyncService or DatabaseHelper.
class WebPatientDashboardScreen extends StatefulWidget {
  const WebPatientDashboardScreen({super.key});

  @override
  State<WebPatientDashboardScreen> createState() =>
      _WebPatientDashboardScreenState();
}

class _WebPatientDashboardScreenState extends State<WebPatientDashboardScreen> {
  bool _isLoading = true;
  List<VitalSigns> _vitals = [];
  Map<String, dynamic>? _latestAnnouncement;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authRepo = context.read<AuthRepository>();
      final user = authRepo.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = "User session expired. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      final supabase = Supabase.instance.client;

      // Fetch vitals from cloud
      final vitalsResponse = await supabase
          .from('vitals')
          .select()
          .eq('user_id', user.id)
          .eq('is_deleted', false)
          .order('timestamp', ascending: false);

      final vitalsData = vitalsResponse as List;
      _vitals = vitalsData.map((row) => VitalSigns.fromMap(row)).toList();

      // Fetch latest announcement
      final annResponse = await supabase
          .from('announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);

      final annData = annResponse as List;
      if (annData.isNotEmpty) {
        _latestAnnouncement = annData.first;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load health records. Check your connection.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthRepository>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.brandGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                        AppColors.brandGreenDark,
                        AppColors.brandGreen,
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
                            "Hi, ${user?.firstName ?? 'Patient'} 👋",
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
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () {
                    context
                        .read<MobileNavigationProvider>()
                        .goToAnnouncements();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
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
          if (_latestAnnouncement != null) ...[
            _buildAnnouncementCard(),
            const SizedBox(height: 20),
          ],
          if (_vitals.isEmpty) ...[
            _buildEmptyState(),
          ] else ...[
            _buildLatestMetrics(),
            const SizedBox(height: 24),
            _buildRecentHistory(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("BARANGAY ANNOUNCEMENT",
                    style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  _latestAnnouncement?['title'] ?? 'New announcement',
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
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
                  color: AppColors.brandGreenLight,
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
    );
  }

  Widget _buildLatestMetrics() {
    final latest = _vitals.first;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brandGreenDark, AppColors.brandGreen],
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildVitalChip("BP", "${latest.systolicBP}/${latest.diastolicBP}", "mmHg", Colors.red),
                _buildVitalChip("HR", "${latest.heartRate}", "bpm", Colors.purple),
                _buildVitalChip("SpO2", "${latest.oxygen}", "%", Colors.blue),
                _buildVitalChip("Temp", "${latest.temperature}", "°C", Colors.orange),
                if (latest.bmi != null)
                  _buildVitalChip("BMI", latest.bmi!.toStringAsFixed(1), "", Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          if (unit.isNotEmpty)
            Text(unit,
                style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRecentHistory() {
    final recent = _vitals.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_rounded,
                color: AppColors.brandGreen, size: 20),
            SizedBox(width: 8),
            Text("Recent Checkups",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
          ],
        ),
        const SizedBox(height: 12),
        ...recent.map((v) {
          final date =
              "${v.timestamp.year}-${v.timestamp.month.toString().padLeft(2, '0')}-${v.timestamp.day.toString().padLeft(2, '0')}";
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor_heart_rounded,
                    color: AppColors.brandGreen),
                const SizedBox(width: 12),
                Text(date,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text("BP ${v.systolicBP}/${v.diastolicBP}",
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
