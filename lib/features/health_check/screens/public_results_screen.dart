import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

// CORE
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/services/database/sync/vitals_sync_handler.dart';
import '../../../core/utils/vital_validator.dart';
import '../../../core/widgets/flow_animated_button.dart';

// MODELS
import '../models/vital_signs_model.dart';

class PublicResultsScreen extends StatefulWidget {
  final String recordId;

  const PublicResultsScreen({
    super.key,
    required this.recordId,
  });

  @override
  State<PublicResultsScreen> createState() => _PublicResultsScreenState();
}

class _PublicResultsScreenState extends State<PublicResultsScreen> {
  bool _isLoading = true;
  VitalSigns? _record;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecord();
  }

  Future<void> _fetchRecord() async {
    try {
      final syncHandler = Provider.of<VitalsSyncHandler>(context, listen: false);
      final record = await syncHandler.fetchVitalSignById(widget.recordId);
      
      if (mounted) {
        setState(() {
          _record = record;
          _isLoading = false;
          if (record == null) {
            _error = "Record not found. It may still be syncing from the Kiosk.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "An error occurred while fetching your report.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading 
          ? _buildLoading() 
          : _error != null 
              ? _buildError() 
              : _buildSuccess(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.brandGreen),
          const SizedBox(height: 24),
          Text("Retrieving your report...", 
            style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 64),
            const SizedBox(height: 24),
            const Text("Something went wrong", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.brandDark)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5)),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _fetchRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Try Again"),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.patientLogin),
              child: const Text("Go to Login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final record = _record!;
    
    return CustomScrollView(
      slivers: [
        // Premium Header
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: AppColors.brandGreen,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text("Digital Summary", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandGreen, Color(0xFF1B5E20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Icon(Icons.health_and_safety_outlined, 
                      size: 200, color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () {
                // Future implementation for sharing PDF/Link
              },
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Section
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Recorded on ${DateFormat('MMMM dd, yyyy').format(record.timestamp)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const Spacer(),
                    const Text("ID: ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(record.id.substring(0, 8), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 32),

                // Clinical Cards
                _buildMetricCard(
                  title: "Blood Pressure",
                  value: "${record.systolicBP}/${record.diastolicBP}",
                  unit: "mmHg",
                  icon: Icons.speed_rounded,
                  eval: VitalValidator.evaluateBP(record.systolicBP, record.diastolicBP),
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  title: "Heart Rate",
                  value: "${record.heartRate}",
                  unit: "bpm",
                  icon: Icons.favorite_rounded,
                  eval: VitalValidator.evaluateHR(record.heartRate),
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  title: "Oxygen",
                  value: "${record.oxygen}",
                  unit: "%",
                  icon: Icons.air_rounded,
                  eval: VitalValidator.evaluateSpO2(record.oxygen),
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  title: "Temperature",
                  value: "${record.temperature}",
                  unit: "°C",
                  icon: Icons.thermostat_rounded,
                  eval: VitalValidator.evaluateTemp(record.temperature),
                ),
                const SizedBox(height: 16),
                if (record.bmi != null)
                  _buildMetricCard(
                    title: "Body Mass Index",
                    value: record.bmi!.toStringAsFixed(1),
                    unit: "kg/m²",
                    icon: Icons.scale_rounded,
                    eval: VitalValidator.evaluateBMI(record.bmi!),
                  ),

                const SizedBox(height: 48),

                // Call to Action
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: AppColors.brandGreen, size: 32),
                      const SizedBox(height: 16),
                      const Text("Save this to your account", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.brandDark)),
                      const SizedBox(height: 8),
                      Text(
                        "Create an account or login to keep a permanent history of your health checks.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700], height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FlowAnimatedButton(
                          child: ElevatedButton(
                            onPressed: () => context.go(AppRoutes.patientLogin),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text("Go to Patient Dashboard", 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required VitalEvaluation eval,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: eval.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: eval.color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.brandDark)),
                    const SizedBox(width: 4),
                    Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: eval.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: eval.color.withValues(alpha: 0.3)),
            ),
            child: Text(
              eval.label.toUpperCase(),
              style: TextStyle(color: eval.color, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
