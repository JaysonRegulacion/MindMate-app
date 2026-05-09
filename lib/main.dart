import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:mindmate/screens/resetpass_screen.dart';
import 'package:mindmate/screens/signin_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindmate/services/notification_service.dart';
import 'package:mindmate/services/app_version_service.dart';
import 'package:mindmate/widgets/update_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  Future<void> requestSmsPermission() async {
  final status = await Permission.sms.request();

  if (status.isGranted) {
    debugPrint("✅ SMS permission granted");
  } else {
    debugPrint("❌ SMS permission denied");
  }
}

  @override
  void initState() {
    super.initState();

    // Start async service initialization in background
    _initializeServices();

    // Setup deep links and auth listener
    _setupAuthListener();
    _setupAppLinks();

    // Check app version after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppVersion();
    });
  }

  Future<void> _initializeServices() async {
    unawaited(NotificationService.initialize());
    unawaited(Supabase.initialize(
      url: 'https://jvvesomjnzzjzakxcdmj.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2dmVzb21qbnp6anpha3hjZG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MTg2ODAsImV4cCI6MjA3MDQ5NDY4MH0.jXb1RM7NlsrLiGuqJCZxkVp6eMD0w0XxX5FM85l5KqY',
    ));

    await requestSmsPermission();

    // Initialize Hive and open boxes in parallel
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('userBox'),
      Hive.openBox('offline_journals'),
      Hive.openBox('offline_moods'),
    ]);

    debugPrint('All services initialized');
  }

  Future<void> _checkAppVersion() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final updateInfo = await AppVersionService.checkForUpdate();

      if (updateInfo != null) {
        await showUpdateDialog(
          context,
          forceUpdate: updateInfo['force_update'] as bool,
          apkUrl: updateInfo['apk_url'] as String,
          latestVersion: updateInfo['latest_version'] as String,
        );
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      // Password recovery
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    });
  }

  void _setupAppLinks() {
    _appLinks = AppLinks();
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (uri == null) return;

      // Password reset link
      if (uri.scheme == 'mindmate' && uri.host == 'reset') {
        final code = uri.queryParameters['code'];
        if (code != null) {
          try {
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
            );
          } catch (e) {
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text("Invalid or expired reset link: $e")),
              );
            }
          }
        }
      }

      // Optional: email verification link
      if (uri.scheme == 'mindmate' && uri.host == 'verify') {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MindMate',
      // Show a lightweight splash screen immediately
      home: const SplashScreen(),
    );
  }
}

/// A simple splash screen while services initialize
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Automatically navigate to SignInScreen after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (Navigator.of(context).canPop()) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
