import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kiosk_application/features/mainmenu/screens/main_menu_screen.dart';
import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/user_history/domain/i_history_repository.dart';
import 'package:kiosk_application/core/providers/language_provider.dart';
import 'package:kiosk_application/features/auth/models/user_model.dart';
import 'package:kiosk_application/l10n/app_localizations.dart';
import '../mocks/test_mocks.dart';

void main() {
  late MockAuthRepository mockAuth;
  late MockHistoryRepository mockHistory;

  setUp(() {
    mockAuth = MockAuthRepository();
    mockHistory = MockHistoryRepository();

    final testUser = User(
      id: '123',
      firstName: 'Jane',
      middleInitial: 'D',
      lastName: 'Doe',
      sitio: 'Villa 1',
      phoneNumber: '09111222333',
      pinCode: '000000',
      gender: 'Male',
      dateOfBirth: DateTime(1990, 1, 1),
      username: 'h260001',
    );

    when(() => mockAuth.currentUser).thenReturn(testUser);
    when(() => mockAuth.users).thenReturn([testUser]);
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.addListener(any())).thenAnswer((_) {});
    when(() => mockAuth.removeListener(any())).thenAnswer((_) {});

    when(() => mockHistory.records).thenReturn([]);
    when(() => mockHistory.isLoading).thenReturn(false);
    when(() => mockHistory.addListener(any())).thenAnswer((_) {});
    when(() => mockHistory.removeListener(any())).thenAnswer((_) {});
  });

  Widget createMainMenu() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<IAuthRepository>.value(value: mockAuth),
        ChangeNotifierProvider<IHistoryRepository>.value(value: mockHistory),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: MainMenuScreen(),
      ),
    );
  }

  group('MainMenuScreen Widget Tests', () {
    testWidgets('renders welcome message with user name', (tester) async {
      await tester.pumpWidget(createMainMenu());
      await tester.pump();

      expect(
          find.text('What would you like to do today, Jane?'), findsOneWidget);
    });

    testWidgets('shows all core health check options', (tester) async {
      await tester.pumpWidget(createMainMenu());
      await tester.pump();

      expect(find.text('Full Health Check'), findsOneWidget);
      expect(find.text('Individual Tests'), findsOneWidget);
      expect(find.text('Health Tips'), findsOneWidget);
      expect(find.text('View History'), findsOneWidget);
    });

    testWidgets('clicking profile icon opens dialog', (tester) async {
      when(() => mockHistory.loadUserHistory(any())).thenAnswer((_) async {});

      await tester.pumpWidget(createMainMenu());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.account_circle_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Villa 1'), findsOneWidget);
      expect(find.text('LOGOUT'), findsOneWidget);
    });
  });
}
