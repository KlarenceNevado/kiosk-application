import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../../auth/models/user_model.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsCard extends StatefulWidget {
  final List<VitalSigns> records;
  final List<User>? users;

  const AdminAnalyticsCard({super.key, required this.records, this.users});

  @override
  State<AdminAnalyticsCard> createState() => _AdminAnalyticsCardState();
}

class _AdminAnalyticsCardState extends State<AdminAnalyticsCard> {
  String _selectedSitio = "All Sitios";
  final List<String> _sitios = [
    "All Sitios",
    "Sitio Ayala",
    "Sitio Mahabang Buhangin",
    "Sitio Sampalucan",
    "Sitio Hulo",
    "Sitio Labak",
    "Sitio Macaraigan",
    "Sitio Gabihan"
  ];

  String _selectedParameter = 'Blood Pressure';
  final List<String> _parameters = [
    'Blood Pressure',
    'Heart Rate',
    'Oxygen (SpO2)',
    'Temperature',
    'BMI',
  ];

  bool _showAiExplanation = true;
  bool _isMaximized = false;
  String _selectedGender = "All Genders";
  final List<String> _genders = ["All Genders", "Male", "Female"];

  void _toggleMaximize() {
    setState(() {
      _isMaximized = !_isMaximized;
    });
    if (_isMaximized) {
      _showMaximizedDialog();
    }
  }

  void _showMaximizedDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          final filteredRecords = _getFilteredRecords();
          
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Barangay Health Intelligence Center", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("Viewing: $_selectedSitio | $_selectedGender", 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _isMaximized = false);
                    Navigator.pop(context);
                  },
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                foregroundColor: AppColors.brandDark,
                actions: [
                  // Sitio Filter in Dialog
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSitio,
                        style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.bold, fontSize: 13),
                        items: _sitios.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            dialogSetState(() => _selectedSitio = val);
                            setState(() => _selectedSitio = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Gender Filter in Dialog
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.bold, fontSize: 13),
                        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            dialogSetState(() => _selectedGender = val);
                            setState(() => _selectedGender = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(32.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildParameterSelector(onSelected: (param) {
                        dialogSetState(() => _selectedParameter = param);
                        setState(() => _selectedParameter = param);
                      }),
                      const SizedBox(height: 32),
                      RepaintBoundary(
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildChart(filteredRecords, isMaximized: true),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildAiInterpretation(filteredRecords),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    ).then((_) {
      if (mounted) setState(() => _isMaximized = false);
    });
  }

  Widget _buildParameterSelector({Function(String)? onSelected}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _parameters.map((param) {
          final isSelected = _selectedParameter == param;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(param,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: AppColors.brandGreen,
              backgroundColor: Colors.grey.shade100,
              onSelected: (selected) {
                if (selected) {
                  if (onSelected != null) {
                    onSelected(param);
                  } else {
                    setState(() => _selectedParameter = param);
                  }
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAiInterpretation(List<VitalSigns> filteredRecords) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showAiExplanation,
          onExpansionChanged: (val) => setState(() => _showAiExplanation = val),
          leading: const Icon(Icons.auto_awesome, color: Colors.blue),
          title: const Text("Intelligent Health Interpretation",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _generateAiExplanation(filteredRecords),
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.brandDark,
                      height: 1.5,
                      fontWeight: FontWeight.w500),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  List<VitalSigns> _getFilteredRecords() {
    List<VitalSigns> filtered = widget.records;

    // 1. Filter by Sitio
    if (_selectedSitio != "All Sitios" && widget.users != null) {
      final sitioUserIds = widget.users!
          .where((u) => u.sitio == _selectedSitio)
          .map((u) => u.id)
          .toSet();
      filtered = filtered.where((r) => sitioUserIds.contains(r.userId)).toList();
    }

    // 2. Filter by Gender
    if (_selectedGender != "All Genders" && widget.users != null) {
      final genderUserIds = widget.users!
          .where((u) => u.gender.toLowerCase() == _selectedGender.toLowerCase())
          .map((u) => u.id)
          .toSet();
      filtered = filtered.where((r) => genderUserIds.contains(r.userId)).toList();
    }

    return filtered;
  }

  String _generateAiExplanation(List<VitalSigns> records) {
    if (records.isEmpty) {
      return "Walang data o record na makikita para sa napiling criteria (No records found for current filters).";
    }

    // Sort records by date to analyze trends
    final sortedRecords = List<VitalSigns>.from(records)
      ..sort((a, b) => a.phtTimestamp.compareTo(b.phtTimestamp));

    double sum1 = 0, sum2 = 0;
    int count = 0;
    
    // Trend analysis variables
    double firstVal = 0;
    double lastVal = 0;

    for (int i = 0; i < sortedRecords.length; i++) {
      var r = sortedRecords[i];
      double val = 0;
      if (_selectedParameter == 'Blood Pressure') {
        sum1 += r.systolicBP;
        sum2 += r.diastolicBP;
        val = r.systolicBP.toDouble();
        count++;
      } else if (_selectedParameter == 'Heart Rate') {
        sum1 += r.heartRate;
        val = r.heartRate.toDouble();
        count++;
      } else if (_selectedParameter == 'Oxygen (SpO2)') {
        sum1 += r.oxygen;
        val = r.oxygen.toDouble();
        count++;
      } else if (_selectedParameter == 'Temperature') {
        sum1 += r.temperature;
        val = r.temperature.toDouble();
        count++;
      } else if (_selectedParameter == 'BMI') {
        if (r.bmi != null && r.bmi! > 0) {
          sum1 += r.bmi!;
          val = r.bmi!;
          count++;
        }
      }
      
      if (i == 0) firstVal = val;
      if (i == sortedRecords.length - 1) lastVal = val;
    }

    if (count == 0) return "Hindi sapat ang data para makabuo ng interpretasyon.";

    double avg1 = sum1 / count;
    double avg2 = sum2 / count;
    
    // Trend direction
    String trendDirection = "";
    if (sortedRecords.length > 1) {
      double diff = lastVal - firstVal;
      if (diff.abs() < (firstVal * 0.05)) {
        trendDirection = "STABLE: Ang trend ay nananatiling pantay sa nakalipas na mga araw.";
      } else if (diff > 0) {
        trendDirection = "UPWARD TREND: May pagtaas sa mga huling reading kumpara sa simula.";
      } else {
        trendDirection = "DOWNWARD TREND: May pagbaba sa mga huling reading kumpara sa simula.";
      }
    }

    String insight = "";
    String recommendation = "";

    if (_selectedParameter == 'Blood Pressure') {
      if (avg1 > 140 || avg2 > 90) {
        insight = "⚠️ HIGH RISK (Hypertensive Zone): Ang average na ${avg1.toInt()}/${avg2.toInt()} ay mataas.";
        recommendation = "Kailangan ng agarang monitoring at limitahan ang maaalat na pagkain sa mga residenteng apektado.";
      } else if (avg1 < 90) {
        insight = "⚠️ LOW RISK (Hypotensive): Ang average ay mababa para sa normal na range.";
        recommendation = "Siguraduhing sapat ang hydration at nutrisyon ng mga residente.";
      } else {
        insight = "✅ OPTIMAL: Ang average na ${avg1.toInt()}/${avg2.toInt()} ay nasa normal na range.";
        recommendation = "Ipagpatuloy ang healthy lifestyle at regular na checkup.";
      }
    } else if (_selectedParameter == 'Heart Rate') {
      if (avg1 > 100) {
        insight = "⚠️ TACHYCARDIA TREND: Mabilis ang tibok ng puso (${avg1.toInt()} bpm).";
        recommendation = "Maaaring sanhi ng stress, init, o pagkapagod. Iwasan ang sobrang kapeina.";
      } else if (avg1 < 60) {
        insight = "⚠️ BRADYCARDIA TREND: Mabagal ang tibok ng puso (${avg1.toInt()} bpm).";
        recommendation = "Bantayan kung may nararamdamang pagkahilo ang mga residente.";
      } else {
        insight = "✅ NORMAL: Maayos ang tibok ng puso (${avg1.toInt()} bpm).";
        recommendation = "Nasa mabuting kalagayan ang cardiovascular health ng grupo.";
      }
    } else if (_selectedParameter == 'Oxygen (SpO2)') {
      if (avg1 < 95) {
        insight = "🚨 CRITICAL: Mababa ang oxygen level (${avg1.toInt()}%).";
        recommendation = "Bantayan ang mga may ubo o hirap huminga. Maaaring kailanganin ng oxygen support.";
      } else {
        insight = "✅ EXCELLENT: Maganda ang saturation ng oxygen (${avg1.toInt()}%).";
        recommendation = "Maayos ang respiratory health sa napiling area.";
      }
    } else if (_selectedParameter == 'Temperature') {
      if (avg1 > 37.8) {
        insight = "🌡️ FEVER ALERT: May trend ng lagnat (${avg1.toStringAsFixed(1)}°C).";
        recommendation = "Maaaring may kumakalat na infection. Siguraduhing may sapat na pahinga at tubig.";
      } else {
        insight = "✅ STABLE TEMP: Normal ang temperatura (${avg1.toStringAsFixed(1)}°C).";
        recommendation = "Walang nakitang laganap na lagnat sa kasalukuyang data.";
      }
    } else if (_selectedParameter == 'BMI') {
      if (avg1 >= 25) {
        insight = "⚖️ OVERWEIGHT TREND: Ang average BMI ay ${avg1.toStringAsFixed(1)}.";
        recommendation = "Magmungkahi ng community exercise programs at diet counseling.";
      } else if (avg1 < 18.5) {
        insight = "⚖️ UNDERWEIGHT TREND: Ang average BMI ay ${avg1.toStringAsFixed(1)}.";
        recommendation = "Maaaring kailanganin ng feeding programs o nutritional support.";
      } else {
        insight = "✅ HEALTHY WEIGHT: Normal ang BMI (${avg1.toStringAsFixed(1)}).";
        recommendation = "Maayos ang nutritional status ng karamihan.";
      }
    }

    String contextualSummary = "Summary para sa $_selectedSitio ($_selectedGender):\n\n";
    contextualSummary += "$insight\n";
    if (trendDirection.isNotEmpty) contextualSummary += "📈 Trend: $trendDirection\n";
    
    // Add Sitio Comparison if "All Sitios" is not selected
    if (_selectedSitio != "All Sitios" && widget.users != null && widget.records.isNotEmpty) {
      double overallSum = 0;
      int overallCount = 0;
      for (var r in widget.records) {
        if (_selectedParameter == 'Blood Pressure') {
          overallSum += r.systolicBP;
          overallCount++;
        } else if (_selectedParameter == 'Heart Rate') {
          overallSum += r.heartRate;
          overallCount++;
        } else if (_selectedParameter == 'Oxygen (SpO2)') {
          overallSum += r.oxygen;
          overallCount++;
        } else if (_selectedParameter == 'Temperature') {
          overallSum += r.temperature;
          overallCount++;
        }
      }
      
      if (overallCount > 0) {
        double overallAvg = overallSum / overallCount;
        double diff = avg1 - overallAvg;
        String comp = "";
        if (diff.abs() > (overallAvg * 0.1)) {
          if (diff > 0) {
            comp = "Ang $_selectedSitio ay may mas mataas na average kumpara sa kabuuan ng Barangay.";
          } else {
            comp = "Ang $_selectedSitio ay may mas mababang average kumpara sa kabuuan ng Barangay.";
          }
          contextualSummary += "📍 Comparison: $comp\n";
        }
      }
    }

    contextualSummary += "💡 Rekomendasyon: $recommendation";

    return contextualSummary;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _getFilteredRecords();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Barangay Health Trends",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  const SizedBox(height: 4),
                  Text("Average vitals over the last 7 active screening days",
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              if (widget.users != null)
                DropdownButton<String>(
                  value: _selectedSitio,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.location_on,
                      size: 16, color: AppColors.brandGreen),
                  style: const TextStyle(
                      color: AppColors.brandDark, fontWeight: FontWeight.bold),
                  items: _sitios
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSitio = val);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: AppColors.brandGreen),
                tooltip: "Maximize View",
                onPressed: _toggleMaximize,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Single-Select Parameters Row
          _buildParameterSelector(),
          const SizedBox(height: 24),
          // Chart
          SizedBox(
            height: 280,
            child: filteredRecords.isEmpty
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
                : RepaintBoundary(child: _buildChart(filteredRecords)),
          ),
          const SizedBox(height: 16),
          // AI Interpretation Tab
          _buildAiInterpretation(filteredRecords),
        ],
      ),
    );
  }

  Widget _buildChart(List<VitalSigns> recordsToUse, {bool isMaximized = false}) {
    final Map<String, List<VitalSigns>> dailyRecords = {};
    for (var r in recordsToUse) {
      final key = DateFormat('yyyy-MM-dd').format(r.phtTimestamp);
      if (!dailyRecords.containsKey(key)) {
        dailyRecords[key] = [];
      }
      dailyRecords[key]!.add(r);
    }

    final sortedDates = dailyRecords.keys.toList()..sort();
    final displayDates = sortedDates.length > 7
        ? sortedDates.sublist(sortedDates.length - 7)
        : sortedDates;

    if (displayDates.isEmpty) {
      return const Center(child: Text("Not enough data to display."));
    }

    List<FlSpot> spotsSys = [];
    List<FlSpot> spotsDia = [];
    List<FlSpot> spotsHR = [];
    List<FlSpot> spotsSpo2 = [];
    List<FlSpot> spotsTemp = [];
    List<FlSpot> spotsBmi = [];

    for (int i = 0; i < displayDates.length; i++) {
      final dayRecords = dailyRecords[displayDates[i]]!;
      double sumSys = 0,
          sumDia = 0,
          sumHr = 0,
          sumSpo2 = 0,
          sumTemp = 0,
          sumBmi = 0;
      int bmiCount = 0;
      for (var r in dayRecords) {
        sumSys += r.systolicBP;
        sumDia += r.diastolicBP;
        sumHr += r.heartRate;
        sumSpo2 += r.oxygen;
        sumTemp += r.temperature;
        if (r.bmi != null && r.bmi! > 0) {
          sumBmi += r.bmi!;
          bmiCount++;
        }
      }
      spotsSys.add(FlSpot(i.toDouble(), sumSys / dayRecords.length));
      spotsDia.add(FlSpot(i.toDouble(), sumDia / dayRecords.length));
      spotsHR.add(FlSpot(i.toDouble(), sumHr / dayRecords.length));
      spotsSpo2.add(FlSpot(i.toDouble(), sumSpo2 / dayRecords.length));
      spotsTemp.add(FlSpot(i.toDouble(), sumTemp / dayRecords.length));
      if (bmiCount > 0) {
        spotsBmi.add(FlSpot(i.toDouble(), sumBmi / bmiCount));
      }
    }

    List<LineChartBarData> bars = [];
    List<HorizontalLine> extraLines = [];
    
    // Dynamic scaling logic
    List<double> allYValues = [];

    HorizontalLineLabel buildLabel(String text, Color color, Alignment align) {
      return HorizontalLineLabel(
        show: true,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        style: TextStyle(
            color: color.withValues(alpha: 0.9), 
            fontWeight: FontWeight.bold, 
            fontSize: isMaximized ? 14 : 11,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
        ),
        labelResolver: (_) => text,
      );
    }

    if (_selectedParameter == 'Blood Pressure') {
      allYValues.addAll(spotsSys.map((s) => s.y));
      allYValues.addAll(spotsDia.map((s) => s.y));
      allYValues.addAll([140, 120, 90, 60]);

      bars.add(LineChartBarData(
          spots: spotsSys,
          color: Colors.red,
          barWidth: isMaximized ? 4 : 3,
          isCurved: true,
          dotData: FlDotData(show: isMaximized)));
      bars.add(LineChartBarData(
          spots: spotsDia,
          color: Colors.blue,
          barWidth: isMaximized ? 4 : 3,
          isCurved: true,
          dotData: FlDotData(show: isMaximized)));

      extraLines.add(HorizontalLine(
          y: 140,
          color: Colors.red.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MATAAS / HIGH (Systolic)", Colors.red, Alignment.topRight)));
      extraLines.add(HorizontalLine(
          y: 120,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("NORMAL MAX (Systolic)", Colors.green, Alignment.bottomRight)));
      extraLines.add(HorizontalLine(
          y: 90,
          color: Colors.orange.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MABABA (Sys) / MATAAS (Dia)", Colors.orange, Alignment.topRight)));
      extraLines.add(HorizontalLine(
          y: 60,
          color: Colors.red.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MABABA / LOW (Diastolic)", Colors.red, Alignment.bottomRight)));
    } else if (_selectedParameter == 'Heart Rate') {
      allYValues.addAll(spotsHR.map((s) => s.y));
      allYValues.addAll([100, 80, 60]);

      bars.add(LineChartBarData(
          spots: spotsHR,
          color: Colors.purple,
          barWidth: isMaximized ? 4 : 3,
          isCurved: true,
          dotData: FlDotData(show: isMaximized)));

      extraLines.add(HorizontalLine(
          y: 100,
          color: Colors.red.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MABILIS / HIGH", Colors.red, Alignment.topRight)));
      extraLines.add(HorizontalLine(
          y: 60,
          color: Colors.red.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MABAGAL / LOW", Colors.red, Alignment.bottomRight)));
      extraLines.add(HorizontalLine(
          y: 80,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("NORMAL", Colors.green, Alignment.topRight)));
    } else if (_selectedParameter == 'Oxygen (SpO2)') {
      allYValues.addAll(spotsSpo2.map((s) => s.y));
      allYValues.addAll([95, 90]);

      bars.add(LineChartBarData(
          spots: spotsSpo2,
          color: Colors.cyan,
          barWidth: isMaximized ? 4 : 3,
          isCurved: true,
          dotData: FlDotData(show: isMaximized)));

      extraLines.add(HorizontalLine(
          y: 95,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("NORMAL (Good)", Colors.green, Alignment.topRight)));
      extraLines.add(HorizontalLine(
          y: 90,
          color: Colors.red.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MABABA / DANGER", Colors.red, Alignment.bottomRight)));
    } else if (_selectedParameter == 'Temperature') {
      allYValues.addAll(spotsTemp.map((s) => s.y));
      allYValues.addAll([37.8, 36.5]);

      bars.add(LineChartBarData(
          spots: spotsTemp,
          color: Colors.orange,
          barWidth: isMaximized ? 4 : 3,
          isCurved: true,
          dotData: FlDotData(show: isMaximized)));

      extraLines.add(HorizontalLine(
          y: 37.8,
          color: Colors.red.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("MAY LAGNAT / FEVER", Colors.red, Alignment.topRight)));
      extraLines.add(HorizontalLine(
          y: 36.5,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("NORMAL", Colors.green, Alignment.bottomRight)));
    } else if (_selectedParameter == 'BMI') {
      allYValues.addAll(spotsBmi.map((s) => s.y));
      allYValues.addAll([25, 18.5, 22]);

      bars.add(LineChartBarData(
          spots: spotsBmi,
          color: Colors.teal,
          barWidth: isMaximized ? 4 : 3,
          isCurved: true,
          dotData: FlDotData(show: isMaximized)));

      extraLines.add(HorizontalLine(
          y: 25,
          color: Colors.orange.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("OVERWEIGHT", Colors.orange, Alignment.topRight)));
      extraLines.add(HorizontalLine(
          y: 18.5,
          color: Colors.orange.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("UNDERWEIGHT", Colors.orange, Alignment.bottomRight)));
      extraLines.add(HorizontalLine(
          y: 22,
          color: Colors.green.withValues(alpha: 0.4),
          strokeWidth: 2,
          dashArray: [5, 5],
          label: buildLabel("NORMAL", Colors.green, Alignment.topRight)));
    }

    double minY = allYValues.reduce((a, b) => a < b ? a : b);
    double maxY = allYValues.reduce((a, b) => a > b ? a : b);
    
    // Add padding for labels
    double range = maxY - minY;
    if (range == 0) range = 10;
    minY -= range * 0.15;
    maxY += range * 0.15;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 5,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
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
              return touchedSpots.asMap().entries.map((entry) {
                final spot = entry.value;
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
