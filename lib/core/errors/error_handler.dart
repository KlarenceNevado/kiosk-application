import 'package:flutter/material.dart';

class ErrorHandler {
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
  }

  static Widget errorWidgetBuilder(FlutterErrorDetails details) {
    // FIXED: Added 'const' to Scaffold and SizedBox
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 80),
            SizedBox(height: 16),
            Text("System Error",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Please contact admin.", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
