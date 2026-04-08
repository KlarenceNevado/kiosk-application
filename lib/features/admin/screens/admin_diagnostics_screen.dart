import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/system/log_manager_service.dart';

class AdminDiagnosticsScreen extends StatefulWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  State<AdminDiagnosticsScreen> createState() => _AdminDiagnosticsScreenState();
}

class _AdminDiagnosticsScreenState extends State<AdminDiagnosticsScreen> {
  final LogManagerService _logManager = LogManagerService();
  List<String> _logFiles = [];
  String? _selectedFile;
  String _logContent = "Select a log file to view...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogList();
  }

  Future<void> _loadLogList() async {
    setState(() => _isLoading = true);
    final logs = await _logManager.listLogs();
    setState(() {
      _logFiles = logs;
      if (logs.isNotEmpty) {
        _selectedFile = logs.first;
        _loadLogContent(logs.first);
      } else {
        _isLoading = false;
      }
    });
  }

  Future<void> _loadLogContent(String fileName) async {
    setState(() => _isLoading = true);
    final content = await _logManager.getLogContent(fileName);
    setState(() {
      _logContent = content;
      _isLoading = false;
    });
  }

  Future<void> _exportLog() async {
    if (_selectedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportPath = '${directory.path}/EXP_${_selectedFile}';
      final file = File(exportPath);
      await file.writeAsString(_logContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Log exported to: $exportPath"),
            action: SnackBarAction(
              label: "OPEN",
              onPressed: () => OpenFile.open(exportPath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("System Diagnostics & Logs", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadLogList,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Log List
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE0E6ED))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Log Archives", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _logFiles.length,
                    itemBuilder: (context, index) {
                      final file = _logFiles[index];
                      final isSelected = _selectedFile == file;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.brandGreen.withValues(alpha: 0.1),
                        title: Text(file, 
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.brandGreen : Colors.black87,
                            )),
                        leading: Icon(Icons.description_outlined, 
                            size: 18, 
                            color: isSelected ? AppColors.brandGreen : Colors.grey),
                        onTap: () {
                          setState(() => _selectedFile = file);
                          _loadLogContent(file);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main: Log Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Viewing: ${_selectedFile ?? 'None'}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text("Export Log"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandDark,
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _selectedFile == null ? null : _exportLog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A), // Slate-900 for terminal feel
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
                        ]
                      ),
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: AppColors.brandGreen))
                        : SingleChildScrollView(
                            child: SelectableText(
                              _logContent,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8), // Slate-400
                                fontFamily: 'Courier New',
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

