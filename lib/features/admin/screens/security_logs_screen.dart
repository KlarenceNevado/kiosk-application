import 'package:flutter/material.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/services/database/database_helper.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  late Future<List<Map<String, dynamic>>> _logsFuture;
  late Future<bool> _integrityFuture;
  late Future<Map<String, dynamic>> _pulseFuture;
  String _filterSeverity = 'ALL';

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = DatabaseHelper.instance.getAuditLogs();
      _integrityFuture = DatabaseHelper.instance.verifyAuditIntegrity();
      _pulseFuture = DatabaseHelper.instance.getSecurityPulse();
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.redAccent;
      case 'HIGH':
        return Colors.orangeAccent;
      case 'MEDIUM':
        return Colors.yellowAccent;
      case 'LOW':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Icons.gpp_maybe;
      case 'HIGH':
        return Icons.warning_amber_rounded;
      case 'MEDIUM':
        return Icons.shield_outlined;
      case 'LOW':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildSecurityPulseHeader() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _pulseFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final pulse = snapshot.data!;
        final bool isWarning = pulse['status'] == 'WARNING';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isWarning
                    ? Colors.redAccent.withValues(alpha: 0.3)
                    : Colors.greenAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPulseStat("TOTAL EVENTS", pulse['total'].toString(),
                  Colors.greenAccent),
              _buildPulseStat(
                  "HIGH RISK", pulse['highRisk'].toString(), Colors.redAccent),
              _buildPulseStat("SYSTEM STATUS", pulse['status'],
                  isWarning ? Colors.redAccent : Colors.greenAccent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPulseStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white24, fontSize: 8, fontFamily: 'Courier')),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)
                ])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Rich Deep Black
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SECURITY AUDIT LOGS",
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            Text("COMMAND CENTER CENTRAL",
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontFamily: 'Courier')),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildIntegrityBanner(),
          _buildSecurityPulseHeader(),
          _buildFilterBar(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(color: Colors.white10),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.greenAccent));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final allLogs = snapshot.data!;
                final filteredLogs = _filterSeverity == 'ALL'
                    ? allLogs
                    : allLogs
                        .where((l) =>
                            (l['severity'] ?? 'LOW').toString().toUpperCase() ==
                            _filterSeverity)
                        .toList();

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    return _buildLogEntry(filteredLogs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityBanner() {
    return FutureBuilder<bool>(
      future: _integrityFuture,
      builder: (context, snapshot) {
        final bool isVerified = snapshot.data ?? false;
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isLoading
                ? Colors.blueGrey.withValues(alpha: 0.1)
                : (isVerified
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLoading
                  ? Colors.blueGrey.withValues(alpha: 0.2)
                  : (isVerified
                      ? Colors.greenAccent.withValues(alpha: 0.3)
                      : Colors.redAccent.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isLoading
                    ? Icons.hourglass_empty
                    : (isVerified ? Icons.verified_user : Icons.gpp_bad),
                color: isLoading
                    ? Colors.blueGrey
                    : (isVerified ? Colors.greenAccent : Colors.redAccent),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? "VERIFYING LOG INTEGRITY..."
                          : (isVerified
                              ? "CHAIN OF TRUST: VERIFIED"
                              : "INTEGRITY ALERT: TAMPERING DETECTED"),
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isLoading
                            ? Colors.blueGrey
                            : (isVerified
                                ? Colors.greenAccent
                                : Colors.redAccent),
                      ),
                    ),
                    if (!isLoading)
                      Text(
                        isVerified
                            ? "Audit logs are cryptographically sealed and immutable."
                            : "WARNING: Log sequence hashing mismatch! Unauthorized modification detected.",
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'Courier'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final severities = ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: severities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sev = severities[index];
          final isSelected = _filterSeverity == sev;
          final color = _getSeverityColor(sev);

          return GestureDetector(
            onTap: () => setState(() => _filterSeverity = sev),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : Colors.white10,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.3), blurRadius: 8)
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  sev,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final String severity = (log['severity'] ?? 'LOW').toString().toUpperCase();
    final Color sevColor = _getSeverityColor(severity);
    final DateTime timestamp =
        DateTime.tryParse(log['timestamp']) ?? DateTime.now();
    final String formattedDate =
        DateTimeUtils.formatPHT(timestamp, 'yyyy-MM-dd HH:mm:ss.SSS');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sevColor.withValues(alpha: 0.1), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getSeverityIcon(severity), color: sevColor, size: 22),
          ),
          title: Text(
            log['action'].toString().toUpperCase(),
            style: TextStyle(
              color: sevColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                DateTimeUtils.formatPHT(timestamp, 'HH:mm:ss'),
                style: const TextStyle(
                    color: Colors.white24, fontSize: 10, fontFamily: 'Courier'),
              ),
              const Text(" | ",
                  style: TextStyle(color: Colors.white12, fontSize: 10)),
              Text(
                log['user_id'] ?? 'SYSTEM',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontFamily: 'Courier'),
              ),
            ],
          ),
          trailing: Icon(Icons.keyboard_arrow_down,
              color: sevColor.withValues(alpha: 0.4), size: 18),
          childrenPadding: const EdgeInsets.all(20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaRow("EVENT_ID", "#${log['id']}"),
            _buildMetaRow("TIMESTAMP", formattedDate),
            const Divider(color: Colors.white10, height: 24),
            _buildMetaRow("DESCRIPTION", log['description'] ?? 'NULL'),
            _buildMetaRow("DEVICE_METADATA", log['device_info'] ?? 'UNKNOWN'),
            _buildMetaRow("NETWORK_ORIGIN", log['ip_address'] ?? '127.0.0.1'),
            const Divider(color: Colors.white10, height: 24),
            _buildHashBlock("SECURE_CHAIN_HASH", log['hash']),
            _buildHashBlock("PREVIOUS_BLOCK_HASH", log['previous_hash']),
          ],
        ),
      ),
    );
  }

  Widget _buildHashBlock(String label, dynamic hashValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 8,
                  fontFamily: 'Courier',
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              hashValue?.toString() ?? 'N/A',
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 9,
                  fontFamily: 'Courier'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'Courier')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security_update_good, size: 64, color: Colors.white10),
          SizedBox(height: 16),
          Text("NO SECURITY EVENTS DETECTED",
              style: TextStyle(
                  color: Colors.white24,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
