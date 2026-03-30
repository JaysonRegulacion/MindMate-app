import 'dart:async';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class JournalRepository {
  final SupabaseClient _supabase;
  static const _offlineBoxName = 'offline_journals';
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  JournalRepository(this._supabase);

  /// Initialize connectivity listener for auto-sync
  void initConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .expand((list) => list)
        .listen((status) {
      if (status != ConnectivityResult.none) {
        print('Connectivity restored, syncing offline journals...');
        syncOfflineJournals();
      }
    });
  }

  /// Cancel connectivity listener
  void disposeConnectivityListener() {
    _connectivitySub?.cancel();
  }

  /// Save a journal (offline-first, UTC timestamp)
  Future<String> saveJournal({
    String? journalId,
    required String content,
  }) async {
    final box = await Hive.openBox(_offlineBoxName);
    final user = _supabase.auth.currentUser!;
    final id = journalId ?? const Uuid().v4();   // permanent ID

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    // Save locally ALWAYS
    await box.put(id, {
      "id": id,
      "user_id": user.id,
      "content": content,
      "created_at": nowUtc, // UTC timestamp
      "synced": false,
    });

    // Try sync if online
    final connection = await Connectivity().checkConnectivity();
    if (connection != ConnectivityResult.none) {
      try {
        if (journalId != null) {
          // UPDATE ONLINE
          await _supabase.from('journals')
              .update({"content": content})
              .eq('id', id);
        } else {
          // CREATE ONLINE
          await _supabase.from('journals').insert({
            "id": id,
            "user_id": user.id,
            "content": content,
            "created_at": nowUtc, // UTC timestamp
          });
        }

        // Mark synced locally
        await box.put(id, {
          "id": id,
          "user_id": user.id,
          "content": content,
          "created_at": nowUtc,
          "synced": true,
        });
      } catch (e) {
        print("Sync failed: $e");
      }
    }

    return id;
  }

  /// Fetch journals (offline + online, merged)
  Future<List<Map<String, dynamic>>> fetchJournals() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final box = await Hive.openBox(_offlineBoxName);

    List<Map<String, dynamic>> offlineJournals = box.values
        .where((j) => j['user_id'] == user.id)
        .map((j) => Map<String, dynamic>.from(j))
        .toList();

    List<Map<String, dynamic>> onlineJournals = [];
    try {
      final res = await _supabase
          .from('journals')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      onlineJournals = List<Map<String, dynamic>>.from(res);

      for (var j in onlineJournals) {
        // Save online journal in Hive
        await box.put(j['id'], {...j, 'synced': true});
      }
    } catch (e) {
      print('Error fetching online journals: $e');
    }

    // Merge, avoiding duplicates using 'id'
    final mergedMap = <String, Map<String, dynamic>>{};
    for (var j in [...offlineJournals, ...onlineJournals]) {
      mergedMap[j['id']] = j;
    }
    final merged = mergedMap.values.toList();

    // Sort by created_at UTC
    merged.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return merged;
  }

  /// Delete a journal
  Future<void> deleteJournal(String id) async {
    final box = await Hive.openBox(_offlineBoxName);
    final journal = box.get(id);

    if (journal != null) {
      try {
        await _supabase.from('journals').delete().eq('id', journal['id']);
      } catch (e) {
        print('Error deleting online journal: $e');
      }
      await box.delete(id);
    }
  }

  /// Sync offline journals to Supabase
  Future<void> syncOfflineJournals() async {
    final box = await Hive.openBox(_offlineBoxName);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = box.values.where((j) => j['synced'] == false);

    for (var j in unsynced) {
      try {
        final exists = await _supabase
            .from('journals')
            .select("id")
            .eq("id", j['id'])
            .maybeSingle();

        if (exists != null) {
          // UPDATE
          await _supabase.from('journals')
              .update({"content": j['content']})
              .eq("id", j['id']);
        } else {
          // INSERT
          await _supabase.from('journals').insert({
            "id": j['id'],
            "user_id": j['user_id'],
            "content": j['content'],
            "created_at": j['created_at'], // UTC timestamp
          });
        }

        await box.put(j['id'], {...j, "synced": true});
      } catch (e) {
        print("Sync error: $e");
      }
    }
  }

  /// Load a journal by ID (offline first, fallback online)
  Future<Map<String, dynamic>?> loadJournal(String id) async {
    final box = await Hive.openBox(_offlineBoxName);
    final offlineJournal = box.get(id);
    if (offlineJournal != null) return Map<String, dynamic>.from(offlineJournal);

    try {
      final res = await _supabase.from('journals').select().eq('id', id).single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('Error loading journal online: $e');
      return null;
    }
  }

  /// Utility: convert UTC string to local DateTime
  static DateTime parseUtcToLocal(String utcString) {
    return DateTime.parse(utcString).toLocal();
  }
}
