import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> analyzeJournal(String journalText) async {
  final url = "https://jvvesomjnzzjzakxcdmj.supabase.co/functions/v1/analyze-journal";

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': journalText}),
    );

    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply']?.trim() ?? "Neutral";
    } else {
      print("Error: ${response.body}");
      return "Neutral";
    }
  } catch (e) {
    print('Exception: $e');
    return "Neutral";
  }
}
