import 'dart:convert';
import 'package:http/http.dart' as http;

class SafetyAIService {
  static const _baseUrl = "https://jvvesomjnzzjzakxcdmj.functions.supabase.co";

  static Future<Map<String, dynamic>> analyzeRisk({
    required String userId,
    required String userName,
    List<Map<String, dynamic>>? moods,
    List<Map<String, dynamic>>? journals,
    List<Map<String, dynamic>>? chats,
  }) async {
    final url = Uri.parse("$_baseUrl/ai-risk");
    final body = {
      "userId": userId,
      "userName": userName,
      "moods": moods ?? [],
      "journals": journals ?? [],
      "chats": chats ?? [],
    };

    try {
      final res = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
      if (res.statusCode != 200) return {"riskScore": 0.0, "riskReason": "safety-ai-unavailable"};

      final parsed = jsonDecode(res.body) as Map<String, dynamic>;
      final score = (parsed['riskScore'] is num) ? (parsed['riskScore'] as num).toDouble() : 0.0;
      final reason = parsed['riskReason']?.toString() ?? "";

      return {"riskScore": score, "riskReason": reason};
    } catch (e) {
      return {"riskScore": 0.0, "riskReason": "safety-ai-exception"};
    }
  }
}
