import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:mindmate/screens/resetpass_screen.dart';
import 'package:mindmate/screens/signin_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindmate/services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize(); 

  await Supabase.initialize(
    url: 'https://jvvesomjnzzjzakxcdmj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2dmVzb21qbnp6anpha3hjZG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MTg2ODAsImV4cCI6MjA3MDQ5NDY4MH0.jXb1RM7NlsrLiGuqJCZxkVp6eMD0w0XxX5FM85l5KqY',
  );

  await Hive.initFlutter();
  await Hive.openBox('userBox');
  await Hive.openBox('offline_journals');

  runApp(const MyApp());

  unawaited(_initializeAsyncServices());
}

Future<void> _initializeAsyncServices() async {
  await Hive.openBox('offline_moods');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    });

    _appLinks = AppLinks();
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (uri != null && uri.scheme == 'mindmate' && uri.host == 'reset') {
        final code = uri.queryParameters['code'];
        if (code != null) {
          try {
            await Supabase.instance.client.auth.exchangeCodeForSession(code);
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
      home: const SignInScreen(),
    );
  }
}
