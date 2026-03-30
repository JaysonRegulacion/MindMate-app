import 'dart:async';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MoodRepository {
  final SupabaseClient _sb;
  MoodRepository(this._sb);

  static const _offlineBox = 'offline_moods';
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  /// Initialize connectivity listener for automatic syncing
  void initConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .expand((list) => list) // Flatten to individual values if stream emits a list
        .listen((status) {
      if (status != ConnectivityResult.none) {
        syncOfflineMoods();
      }
    });
  }

  /// Cancel connectivity listener (call on dispose)
  void disposeConnectivityListener() {
    _connectivitySub?.cancel();
  }

  /// Save mood (online first, fallback offline)
  Future<Map<String, dynamic>> saveMood({
    required String mainMood,
    String? subMood,
    String? tip,
    String? note,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final nowUtc = DateTime.now().toUtc(); // Always store UTC in DB
    final payload = {
      'id': const Uuid().v4(),
      'user_id': user.id,
      'main_mood': mainMood,
      'sub_mood': subMood,
      'tip': tip,
      'note': note,
      'created_at': nowUtc.toIso8601String(),
    };

    try {
      final res = await _sb.from('moods').insert(payload).select();
      if (res.isNotEmpty) {
        final map = Map<String, dynamic>.from(res.first);
        // Convert created_at to local before returning
        map['created_at'] =
            DateTime.parse(map['created_at']).toLocal().toIso8601String();
        return map;
      }
      throw Exception("Insert returned empty response");
    } catch (_) {
      final box = await Hive.openBox(_offlineBox);
      await box.put(payload['id'], {...payload, 'synced': false});
      // Convert created_at to local before returning
      return {
        ...payload,
        'created_at': nowUtc.toLocal().toIso8601String(),
        'synced': false
      };
    }
  }

  /// Fetch moods for the last `days` days (online + offline)
  Future<List<Map<String, dynamic>>> fetchRecentMoods({int days = 7}) async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];

    final box = await Hive.openBox(_offlineBox);

    // Offline moods
    final offlineMoods = box.values
        .where((m) => m['user_id'] == user.id)
        .map((m) {
          final copy = Map<String, dynamic>.from(m);
          copy['created_at'] =
              DateTime.parse(copy['created_at']).toLocal().toIso8601String();
          return copy;
        })
        .toList();

    // Calculate threshold
    final threshold = DateTime.now().subtract(Duration(days: days - 1)).toUtc();

    // Online moods
    List<Map<String, dynamic>> onlineMoods = [];
    try {
      final res = await _sb
          .from('moods')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', threshold.toIso8601String())
          .order('created_at', ascending: false);

      onlineMoods = res.map<Map<String, dynamic>>((m) {
        final map = Map<String, dynamic>.from(m);
        // Convert to local
        map['created_at'] =
            DateTime.parse(map['created_at']).toLocal().toIso8601String();
        return map;
      }).toList();

      // Cache online moods
      for (var m in onlineMoods) {
        await box.put(m['id'], {...m, 'synced': true});
      }
    } catch (_) {}

    // Merge offline + online, remove duplicates
    final merged = {for (var m in [...onlineMoods, ...offlineMoods]) m['id']: m}
        .values
        .toList();

    // Sort by newest first
    merged.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return merged;
  }

  /// Load recent moods (latest `limit` entries) for the current user
  Future<List<Map<String, dynamic>>> loadRecentMoods({int limit = 5}) async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];

    final moods = await fetchMoods(); // already returns merged online + offline
    return moods.take(limit).toList();
  }

  /// Fetch moods (online preferred, fallback offline)
  Future<List<Map<String, dynamic>>> fetchMoods() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];

    final box = await Hive.openBox(_offlineBox);

    // Offline moods
    List<Map<String, dynamic>> offlineMoods = box.values
        .where((m) => m['user_id'] == user.id)
        .map((m) {
          final copy = Map<String, dynamic>.from(m);
          copy['created_at'] =
              DateTime.parse(copy['created_at']).toLocal().toIso8601String();
          return copy;
        })
        .toList();

    // Online moods
    List<Map<String, dynamic>> onlineMoods = [];
    try {
      final res = await _sb
          .from('moods')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      onlineMoods = res.map<Map<String, dynamic>>((m) {
        final map = Map<String, dynamic>.from(m);
        map['created_at'] =
            DateTime.parse(map['created_at']).toLocal().toIso8601String();
        return map;
      }).toList();

      // Cache online moods locally
      for (var m in onlineMoods) {
        await box.put(m['id'], {...m, 'synced': true});
      }
    } catch (_) {}

    // Merge both (avoid duplicates)
    final merged = {for (var m in [...onlineMoods, ...offlineMoods]) m['id']: m}
        .values
        .toList();

    // Sort: unsynced first, then newest
    merged.sort((a, b) {
      final aSynced = a['synced'] == true;
      final bSynced = b['synced'] == true;

      if (aSynced != bSynced) return aSynced ? 1 : -1;

      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return merged;
  }

  /// Update offline mood note
  Future<void> updateOfflineMoodNote({
    required String mainMood,
    String? subMood,
    required String note,
  }) async {
    final box = await Hive.openBox(_offlineBox);
    final keys = box.keys.toList();

    for (var i = keys.length - 1; i >= 0; i--) {
      final data = box.get(keys[i]);
      if (data['main_mood'] == mainMood &&
          (subMood == null || data['sub_mood'] == subMood) &&
          data['synced'] == false) {
        await box.put(keys[i], {...data, 'note': note});
        break;
      }
    }
  }

  /// Sync unsynced moods when online
  Future<void> syncOfflineMoods() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    final box = await Hive.openBox(_offlineBox);
    final unsynced = box.values.where((m) => m['synced'] == false);

    for (var mood in unsynced) {
      try {
        await _sb.from('moods').insert({
          'id': mood['id'],
          'user_id': mood['user_id'],
          'main_mood': mood['main_mood'],
          'sub_mood': mood['sub_mood'],
          'tip': mood['tip'],
          'note': mood['note'],
          'created_at': mood['created_at'], // already local in Hive
        });
        await box.put(mood['id'], {...mood, 'synced': true});
      } catch (_) {}
    }
  }
}
