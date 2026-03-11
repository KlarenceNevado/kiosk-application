import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/routes.dart';
import 'core/services/system/config_service.dart';
import 'core/services/security/encryption_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/user_history/data/history_repository.dart';
import 'features/patient/data/mobile_navigation_provider.dart';
import 'main_kiosk.dart'; // for LanguageProvider
import 'features/patient/patient_app_theme.dart';
import 'core/constants/app_colors.dart';
import 'l10n/app_localizations.dart';
import 'features/patient/widgets/announcement_notification_listener.dart';
import 'core/services/security/notification_service.dart';
import 'core/services/system/app_environment.dart';
import 'features/chat/data/chat_repository.dart';
import 'core/services/database/sync_service.dart';

/// THE RULE: runApp() MUST be the very first thing that runs.
/// ALL async initialization happens inside the widget tree,
/// so the splash screen is shown IMMEDIATELY on first frame — no black screen.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.mobilePatient);

  // Ensure the OS keyboard is not suppressed and UI is edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // ↓ synchronous — no awaits here
  runApp(const MobileBootstrapApp());
}

/// Bootstrap widget that handles async initialization while
/// showing a branded splash screen immediately on first render.
class MobileBootstrapApp extends StatefulWidget {
  const MobileBootstrapApp({super.key});

  @override
  State<MobileBootstrapApp> createState() => _MobileBootstrapAppState();
}

class _MobileBootstrapAppState extends State<MobileBootstrapApp> {
  bool _initialized = false;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 0. Timezone Initialization
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (e) {
      debugPrint("⚠️ Timezone: $e");
    }

    // Initialize Local Notifications Service
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint("⚠️ NotificationService: $e");
    }

    // 1. Load .env
    try {
      await dotenv.load(fileName: "assets/.env");
    } catch (e) {
      debugPrint("⚠️ .env load: $e");
    }

    // 2. Supabase
    try {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
    } catch (e) {
      debugPrint("⚠️ Supabase: $e");
    }

    // 3. Encryption
    try {
      await EncryptionService().init();
    } catch (e) {
      debugPrint("⚠️ Encryption: $e");
    }

    // 4. Config
    try {
      await ConfigService().loadSettings();
    } catch (e) {
      debugPrint("⚠️ Config: $e");
    }

    // 5. Sync Service (Listeners & Backfill)
    try {
      SyncService().startSyncLoop();
    } catch (e) {
      debugPrint("⚠️ SyncService: $e");
    }

    // Mark ready — triggers rebuild into the full app
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    // ── Phase 1: Show branded splash while initializing ──────────────────
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: Colors.white),
        home: const _SplashLoadingScreen(),
      );
    }

    // ── Phase 2: Initialization complete — show full app ─────────────────
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepository()),
        ChangeNotifierProvider(create: (_) => HistoryRepository()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
        ChangeNotifierProvider(create: (_) => ChatRepository()),
      ],
      child: AnnouncementNotificationListener(
        messengerKey: _messengerKey,
        child: MaterialApp.router(
          scaffoldMessengerKey: _messengerKey,
          title: 'Isla Verde Health Mobile',
          debugShowCheckedModeBanner: false,
          theme: PatientAppTheme.lightTheme,
          routerConfig: patientRouter,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('fil'),
          ],
        ),
      ),
    );
  }
}

/// Immediately-visible branded splash shown during async initialization.
/// Pure Stateless — no async logic, renders on the very first frame.
class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand icon
            _PulsingLogo(),
            SizedBox(height: 48),
            Text(
              "Isla Verde Health",
              style: TextStyle(
                color: AppColors.brandDark,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Patient Companion Portal",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 64),
            CircularProgressIndicator(color: AppColors.brandGreen),
            SizedBox(height: 16),
            Text(
              "Loading...",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple animated pulsing logo widget.
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: AppColors.brandGreenLight,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandGreen.withValues(alpha: 0.25),
              blurRadius: 32,
              spreadRadius: 8,
            ),
          ],
        ),
        child: const Icon(
          Icons.monitor_heart_rounded,
          size: 88,
          color: AppColors.brandGreenDark,
        ),
      ),
    );
  }
}
