import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiosk_application/apps/kiosk/main_kiosk.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Tests', () {
    testWidgets('Full User Registration and Login Flow', (tester) async {
      // 1. Initialize the app
      app.main();
      await tester.pumpAndSettle();

      // 2. Start at Login, navigate to Register
      expect(find.text('Kiosk Access'), findsOneWidget);
      final createBtn = find.text('No Account? Create New Record');
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // 3. Verify on Registration page
      expect(find.text('New Patient Registration'), findsOneWidget);

      // 4. Fill registration form
      await tester.enterText(find.byType(TextField).at(0), 'Alice'); // First Name
      await tester.enterText(find.byType(TextField).at(1), 'Smith'); // Last Name
      await tester.enterText(find.byType(TextField).at(2), 'A');     // M.I.
      await tester.enterText(find.byType(TextField).at(3), '09223334444'); // Phone
      
      // 5. Submit registration
      final regBtn = find.text('Create Patient Record');
      await tester.tap(regBtn);
      await tester.pumpAndSettle();

      // 6. Should navigate back to login
      expect(find.text('Kiosk Access'), findsOneWidget);
    });
  });
}
