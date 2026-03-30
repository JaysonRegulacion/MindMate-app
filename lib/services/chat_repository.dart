import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  final SupabaseClient supabase;

  ChatRepository(this.supabase);

  /// Save a new chat message (user or AI)
  Future<Map<String, dynamic>?> saveMessage({
    required String userId,
    String? moodId,
    String? journalId,
    required String role, // "user" or "ai"
    required String content,
    String? moodText,
  }) async {
    try {
      // 1. Save message into chat_messages
      final response = await supabase.from('chat_messages').insert({
        'user_id': userId,
        'mood_id': moodId,
        'journal_id': journalId,
        'role': role,
        'content': content,
      }).select().maybeSingle();

      // 2. If first user message and moodId exists → update moods.note
      if (role == "user" && moodId != null) {
        final existingChats = await supabase
            .from('chat_messages')
            .select('id')
            .eq('mood_id', moodId)
            .eq('user_id', userId);

        if (existingChats.length == 1) {
          await supabase.from('moods').update({
            'note': content,
          }).eq('id', moodId);
        }
      }

      return response;
    } catch (e) {
      print("❌ saveMessage error: $e");
      return null;
    }
  }

  /// Load all chat messages for a user
  Future<List<Map<String, dynamic>>> loadMessages(String? userId) async {
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("❌ loadMessages error: $e");
      return [];
    }
  }

  // Load recent moods for a user
  Future<List<Map<String, dynamic>>> loadMoodHistory(String userId,
      {int limit = 15}) async {
    try {
      final res = await supabase
          .from('moods')
          .select('id, main_mood, note, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("❌ loadMoodHistory error: $e");
      return [];
    }
  }

  // Load recent journal entries for a user
  Future<List<Map<String, String>>> loadJournalHistory(String userId,
      {int limit = 5}) async {
    try {
      final res = await supabase
          .from('journals')
          .select('content, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List).map((j) {
        return {
          "role": "user",
          "content": " ${j['content']}",
        };
      }).toList();
    } catch (e) {
      print("❌ loadJournalHistory error: $e");
      return [];
    }
  }
}
