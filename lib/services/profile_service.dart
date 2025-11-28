import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==============================
  // USER PROFILE
  // ==============================
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select('id, first_name, last_name, email, avatar_url, created_at')
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    String? avatarUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No user logged in.');

    final updates = {
      'first_name': firstName,
      'last_name': lastName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('profiles').update(updates).eq('id', user.id);
  }

  // ==============================
  // MOOD UTILS
  // ==============================
  int _moodToScore(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return 5;
      case 'calm':
        return 4;
      case 'tired':
        return 3;
      case 'sad':
        return 2;
      case 'angry':
        return 1;
      default:
        return 3;
    }
  }

  // Fetch all moods for the current user
  Future<List<Map<String, dynamic>>> fetchAllMoods() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('moods')
        .select('created_at, main_mood')
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // Total mood logs
  Future<int> fetchTotalMoodLogs() async {
    final moods = await fetchAllMoods();
    return moods.length;
  }

  // Average mood for the last 7 days
  Future<double> fetchAverageMoodThisWeek() async {
    final moods = await fetchAllMoods();
    final startOfWeek = DateTime.now().subtract(const Duration(days: 7));

    final recentMoods = moods.where((m) {
      final date = DateTime.parse(m['created_at']);
      return date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek);
    }).toList();

    if (recentMoods.isEmpty) return 0;

    final scores = recentMoods.map((m) => _moodToScore(m['main_mood'])).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return double.parse(avg.toStringAsFixed(1));
  }

  // Longest positive streak
  Future<int> fetchLongestPositiveStreak() async {
    final moods = await fetchAllMoods();
    if (moods.isEmpty) return 0;

    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? prevDate;

    for (final mood in moods) {
      final score = _moodToScore(mood['main_mood']);
      final createdAt = DateTime.parse(mood['created_at']);

      if (score >= 4) {
        if (prevDate == null || createdAt.difference(prevDate).inDays <= 1) {
          currentStreak++;
        } else {
          currentStreak = 1;
        }
        longestStreak = max(longestStreak, currentStreak);
      } else {
        currentStreak = 0;
      }

      prevDate = createdAt;
    }

    return longestStreak;
  }

  // ==============================
  // AVATAR UPLOAD
  // ==============================
  Future<String> uploadAvatar(File file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("No user logged in.");

    final filePath =
        'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage.from('avatars').upload(filePath, file);

    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

    return publicUrl;
  }

  // ==============================
  // EMERGENCY CONTACTS
  // ==============================
  Future<List<Map<String, dynamic>>> fetchEmergencyContacts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('emergency_contacts')
        .select('id, name, phone_number, relationship, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phoneNumber,
    required String relationship,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final existingContacts = await fetchEmergencyContacts();
    if (existingContacts.length >= 3) {
      throw Exception('You can only have up to 3 emergency contacts.');
    }

    if (name.isEmpty || phoneNumber.isEmpty || relationship.isEmpty) {
      throw Exception('Please fill in all contact fields.');
    }

    await _supabase.from('emergency_contacts').insert({
      'user_id': user.id,
      'name': name,
      'phone_number': phoneNumber,
      'relationship': relationship,
    });
  }

  Future<void> updateEmergencyContact({
    required String id,
    required String name,
    required String phoneNumber,
    required String relationship,
  }) async {
    if (name.isEmpty || phoneNumber.isEmpty || relationship.isEmpty) {
      throw Exception('Please fill in all contact fields before saving.');
    }

    await _supabase.from('emergency_contacts').update({
      'name': name,
      'phone_number': phoneNumber,
      'relationship': relationship,
    }).eq('id', id);
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _supabase.from('emergency_contacts').delete().eq('id', id);
  }
}
