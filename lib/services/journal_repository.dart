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
        syncOfflineJournals();
      }
    });
  }

  /// Cancel connectivity listener
  void disposeConnectivityListener() {
    _connectivitySub?.cancel();
  }

  /// Save a journal (offline-first)
  Future<String> saveJournal({
    String? journalId,
    required String title,
    required String content,
    String? mood,
  }) async {
    final box = await Hive.openBox(_offlineBoxName);
    final user = _supabase.auth.currentUser!;
    final id = journalId ?? const Uuid().v4();

    // Check if offline journal exists
    final offlineJournal = box.get(id);
    final supabaseId = offlineJournal?['idOnline'];

    final payload = {
      'id': id,
      'user_id': user.id,
      'title': title.trim(),
      'content': content.trim(),
      'mood': mood,
      'created_at': DateTime.now().toIso8601String(),
      'synced': false,
    };

    // Save offline first
    await box.put(id, {...offlineJournal ?? {}, ...payload});

    final connection = await Connectivity().checkConnectivity();
    if (connection != ConnectivityResult.none) {
      try {
        if (supabaseId != null) {
          // Update existing online journal
          await _supabase.from('journals').update({
            'title': title.trim(),
            'content': content.trim(),
            'mood': mood,
          }).eq('id', supabaseId).select();
        } else {
          // Insert new online journal
          final res = await _supabase.from('journals').insert({
            'user_id': user.id,
            'title': title.trim(),
            'content': content.trim(),
            'mood': mood,
          }).select();

          if (res.isNotEmpty) {
            payload['idOnline'] = res.first['id'];
          }
        }

        payload['synced'] = true;
        await box.put(id, {...payload});
      } catch (_) {}
    }

    return id;
  }

  /// Fetch journals (offline + online, merged)
  Future<List<Map<String, dynamic>>> fetchJournals() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final box = await Hive.openBox(_offlineBoxName);

    // Offline journals
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

      // Cache online journals locally
      for (var j in onlineJournals) {
        await box.put(j['id'], {...j, 'synced': true});
      }
    } catch (_) {}

    // Merge, avoid duplicates
    final merged = {
      for (var j in [...offlineJournals, ...onlineJournals]) j['idOnline'] ?? j['id']: j
    }.values.toList();

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

  /// Delete a journal
  Future<void> deleteJournal(String id) async {
    final box = await Hive.openBox(_offlineBoxName);
    final journal = box.get(id);

    final isOffline = journal?['synced'] == false;

    if (!isOffline) {
      try {
        await _supabase.from('journals').delete().eq('id', id);
      } catch (_) {
        // Ignore network errors
      }
    }

    await box.delete(id);
  }

  /// Sync offline journals to Supabase
  Future<void> syncOfflineJournals() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final box = await Hive.openBox(_offlineBoxName);
    final unsynced = box.values.where((j) => j['synced'] == false);

    for (var journal in unsynced) {
      try {
        final res = await _supabase.from('journals').insert({
          'user_id': journal['user_id'],
          'title': journal['title'],
          'content': journal['content'],
          'mood': journal['mood'],
        }).select();

        if (res.isNotEmpty) {
          final onlineId = res.first['id'];
          final syncedJournal = {
            ...journal,
            'id': onlineId,
            'synced': true,
          };
          await box.put(onlineId, syncedJournal); // replace offline key
          await box.delete(journal['id']); // delete old offline key
        }
      } catch (_) {}
    }
  }

  /// Load a journal by ID (offline first, fallback online)
  Future<Map<String, dynamic>?> loadJournal(String id) async {
    final box = await Hive.openBox('offline_journals');
    final offlineJournal = box.get(id);
    if (offlineJournal != null) return Map<String, dynamic>.from(offlineJournal);

    try {
      final res = await _supabase.from('journals').select().eq('id', id).single();
      return Map<String, dynamic>.from(res);
    } catch (_) {
      return null;
    }
  }
}
