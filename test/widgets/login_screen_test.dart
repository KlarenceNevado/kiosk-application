import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kiosk_application/features/auth/screens/login_screen.dart';
import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/auth/models/user_model.dart';
import 'package:kiosk_application/l10n/app_localizations.dart';
import 'package:kiosk_application/core/services/system/app_environment.dart';
import '../mocks/test_mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    // Default mock behavior
    when(() => mockAuthRepository.users).thenReturn([]);
    when(() => mockAuthRepository.isLoading).thenReturn(false);
    when(() => mockAuthRepository.addListener(any())).thenAnswer((_) {});
    when(() => mockAuthRepository.removeListener(any())).thenAnswer((_) {});

    // Ensure we are in a predictable environment mode
    AppEnvironment().setMode(AppMode.kiosk);
  });

  Widget createLoginScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<IAuthRepository>.value(
            value: mockAuthRepository),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('shows warning when no users are found', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('No records found on this kiosk.'), findsOneWidget);
    });

    testWidgets('shows user search field when users exist', (tester) async {
      final testUser = User(
        id: '1',
        firstName: 'John',
        middleInitial: 'M',
        lastName: 'Doe',
        sitio: 'Purok 1',
        phoneNumber: '09123456789',
        pinCode: '123456',
        gender: 'Male',
        dateOfBirth: DateTime(1990, 1, 1),
      );

      when(() => mockAuthRepository.users).thenReturn([testUser]);

      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.byIcon(Icons.person_search_rounded), findsOneWidget);
      expect(find.text('Find Your Account'), findsOneWidget);
    });

    testWidgets('filtering logic shows suggestions', (tester) async {
      final testUser = User(
        id: '1',
        firstName: 'John',
        middleInitial: 'M',
        lastName: 'Doe',
        sitio: 'Purok 1',
        phoneNumber: '09123456789',
        pinCode: '123456',
        gender: 'Male',
        dateOfBirth: DateTime(1990, 1, 1),
      );

      when(() => mockAuthRepository.users).thenReturn([testUser]);

      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      // Enter "Jo" into search
      await tester.enterText(find.byType(TextField).first, 'Jo');
      await tester.pump();

      // Should show suggestion in the overlay
      expect(find.text('John Doe'),
          findsWidgets); // One in field, one in suggestion
    });
  });
}
