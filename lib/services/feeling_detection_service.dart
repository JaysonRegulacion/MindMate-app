import 'dart:convert';
import 'package:http/http.dart' as http;

class FeelingDetectionService {
  final String apiUrl;

  FeelingDetectionService({required this.apiUrl});

  Future<Map<String, dynamic>?> detectFeeling(String journal) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"journal": journal}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          // Groq API response from your Deno server
          return jsonData['data'];
        }
      } else {
        print('Error calling feeling API: ${response.statusCode}');
      }
    } catch (e) {
      print('Feeling detection failed: $e');
    }
    return null;
  }
}
