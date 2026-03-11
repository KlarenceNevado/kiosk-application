import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../health_check/models/vital_signs_model.dart';
import 'package:intl/intl.dart';

/// A polished, full-featured analytics chart that plots all 5 vital sign
/// series (Systolic BP, Diastolic BP, Heart Rate, SpO2, Temperature) over
/// the last 7 active days.  Each series can be toggled independently using
/// filter chips at the top.
class AdminAnalyticsCard extends StatefulWidget {
  final List<VitalSigns> records;

  const AdminAnalyticsCard({super.key, required this.records});

  @override
  State<AdminAnalyticsCard> createState() => _AdminAnalyticsCardState();
}

class _AdminAnalyticsCardState extends State<AdminAnalyticsCard> {
  // Active filter toggles — all ON by default.
  final Map<String, bool> _filters = {
    'Systolic BP': true,
    'Diastolic BP': true,
    'Heart Rate': false,
    'SpO2': false,
    'Temperature': false,
  };

  static const Map<String, Color> _seriesColors = {
    'Systolic BP': Color(0xFFE53935),
    'Diastolic BP': Color(0xFF1E88E5),
    'Heart Rate': Color(0xFF8E24AA),
    'SpO2': Color(0xFF00ACC1),
    'Temperature': Color(0xFFFB8C00),
  };

  static const Map<String, IconData> _seriesIcons = {
    'Systolic BP': Icons.favorite,
    'Diastolic BP': Icons.water_drop,
    'Heart Rate': Icons.monitor_heart,
    'SpO2': Icons.air,
    'Temperature': Icons.thermostat,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text("Barangay Health Trends",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 4),
          Text("Average vitals over the last 7 active screening days",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          // Filter Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filters.keys.map((key) {
              final isActive = _filters[key]!;
              final color = _seriesColors[key]!;
              final icon = _seriesIcons[key]!;
              return FilterChip(
                avatar: Icon(icon,
                    size: 16, color: isActive ? Colors.white : color),
                label: Text(key,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : color)),
                selected: isActive,
                selectedColor: color,
                backgroundColor: color.withValues(alpha: 0.08),
                checkmarkColor: Colors.white,
                side: BorderSide(
                    color: isActive ? color : color.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onSelected: (val) => setState(() => _filters[key] = val),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Chart
          SizedBox(
            height: 280,
            child: widget.records.isEmpty
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("No records available for analytics.",
                          style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ))
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // 1. Group records by day
    final Map<String, List<VitalSigns>> dailyRecords = {};
    for (var r in widget.records) {
      final key = DateFormat('yyyy-MM-dd').format(r.phtTimestamp);
      if (!dailyRecords.containsKey(key)) {
        dailyRecords[key] = [];
      }
      dailyRecords[key]!.add(r);
    }

    // 2. Sort and take last 7 active days
    final sortedDates = dailyRecords.keys.toList()..sort();
    final displayDates = sortedDates.length > 7
        ? sortedDates.sublist(sortedDates.length - 7)
        : sortedDates;

    if (displayDates.isEmpty) {
      return const Center(child: Text("Not enough data to display."));
    }

    // 3. Compute daily averages for each series
    List<FlSpot> spotsFor(String key) {
      List<FlSpot> spots = [];
      for (int i = 0; i < displayDates.length; i++) {
        final dayRecords = dailyRecords[displayDates[i]]!;
        double sum = 0;
        for (var r in dayRecords) {
          switch (key) {
            case 'Systolic BP':
              sum += r.systolicBP;
              break;
            case 'Diastolic BP':
              sum += r.diastolicBP;
              break;
            case 'Heart Rate':
              sum += r.heartRate;
              break;
            case 'SpO2':
              sum += r.oxygen;
              break;
            case 'Temperature':
              sum += r.temperature;
              break;
          }
        }
        spots.add(FlSpot(i.toDouble(), sum / dayRecords.length));
      }
      return spots;
    }

    // 4. Build active line bars
    List<LineChartBarData> bars = [];
    for (var entry in _filters.entries) {
      if (!entry.value) continue;
      final color = _seriesColors[entry.key]!;
      bars.add(LineChartBarData(
        spots: spotsFor(entry.key),
        isCurved: true,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.06),
        ),
      ));
    }

    if (bars.isEmpty) {
      return Center(
          child: Text("Select at least one vital sign to display.",
              style: TextStyle(color: Colors.grey.shade400)));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1, // Show every day cleanly
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < displayDates.length) {
                  final date = DateTime.parse(displayDates[value.toInt()]);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(DateFormat('MMM d').format(date),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: bars,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              final activeKeys = _filters.entries
                  .where((e) => e.value)
                  .map((e) => e.key)
                  .toList();
              return touchedSpots.asMap().entries.map((entry) {
                final idx = entry.key;
                final spot = entry.value;
                final label = idx < activeKeys.length ? activeKeys[idx] : '';
                final color = _seriesColors[label] ?? Colors.white;
                return LineTooltipItem(
                  '$label: ${spot.y.toStringAsFixed(1)}',
                  TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
