import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeAuthController {
  StreamSubscription<AuthState>? _authSub;

  void start(void Function() onLogin) {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) onLogin();
    });
  }

  void dispose() => _authSub?.cancel();
}
