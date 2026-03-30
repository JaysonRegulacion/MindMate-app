import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const _baseUrl = "https://jvvesomjnzzjzakxcdmj.functions.supabase.co";

  /// STREAMING VERSION
    static Stream<String> chatWithAIStream(
    String message, {
    List<Map<String, dynamic>>? conversationHistory,
    List<Map<String, dynamic>>? recentMoods,
    List<Map<String, dynamic>>? recentJournals,
  }) async* {
    try {
      final body = {
        "message": message,
        "history": conversationHistory ?? [],
        if (recentMoods != null) "recentMoods": recentMoods,
        if (recentJournals != null) "recentJournals": recentJournals,
      };

      final request = http.Request("POST", Uri.parse("$_baseUrl/ai-chat"));
      request.headers["Content-Type"] = "application/json";
      request.body = jsonEncode(body);

      final response = await request.send();

      if (response.statusCode != 200) {
        yield "⚠️ Service temporarily unavailable.";
        return;
      }

      String buffer = "";

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Split complete lines
        final lines = buffer.split(RegExp(r'\r?\n'));
        buffer = ""; // reset buffer

        for (int i = 0; i < lines.length; i++) {
          var line = lines[i];

          // If this is the last line and doesn't end with newline, keep it in buffer
          if (i == lines.length - 1 && !line.endsWith('\n')) {
            buffer = line;
            break;
          }

          line = line.trim();
          if (!line.startsWith("data:")) continue;

          final jsonPart = line.substring(5).trim();
          if (jsonPart == "[DONE]") return;

          try {
            final data = jsonDecode(jsonPart);
            final delta = data["choices"]?[0]?["delta"]?["content"];
            if (delta != null && delta.isNotEmpty) {
              yield delta; // send token to UI
            }
          } catch (_) {
            // ignore malformed JSON
          }
        }
      }
    } catch (e) {
      yield "⚠️ Network issue, please try again.";
    }
  }
}
