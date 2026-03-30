import 'package:supabase_flutter/supabase_flutter.dart';

class EmotionDetectionService {
  final SupabaseClient supabase;

  EmotionDetectionService(this.supabase);

  Future<Map<String, dynamic>?> detect(String text) async {
    try {
      final res = await supabase.functions.invoke(
        'mood-detect',
        body: {'text': text},
      );

      if (res.data == null) return null;
      return Map<String, dynamic>.from(res.data);
    } catch (_) {
      // Never block journaling if AI fails
      return null;
    }
  }
}
