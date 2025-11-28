import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  final SupabaseClient supabase;

  ChatRepository(this.supabase);

  /// Save a new chat message (user or AI)
  Future<Map<String, dynamic>?> saveMessage({
    required String userId,
    String? moodId,
    required String role, // "user" or "ai"
    required String content, String? moodText,
  }) async {
    try {
      // 1. Save message into chat_messages
      final response = await supabase.from('chat_messages').insert({
        'user_id': userId,
        'mood_id': moodId,
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
          // this means it’s the FIRST user message linked to this mood
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

      return response;
    } catch (e) {
      print("❌ loadMessages error: $e");
      return [];
    }
  }
}
