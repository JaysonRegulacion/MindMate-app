import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for AI chat + motivational tips
class AIService {
  static const _baseUrl =
      "https://jvvesomjnzzjzakxcdmj.functions.supabase.co";

  /// Chat freely with MindMate AI
  static Future<String> chatWithAI(String message) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/ai-chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception("Failed to chat: ${data['error'] ?? response.body}");
      }

      return data["reply"]?.toString().trim() ?? "I'm here to listen.";
    } catch (e) {
      // Offline fallback or API error
      return "Sorry, I couldn’t connect right now. Please try again.";
    }
  }
}
