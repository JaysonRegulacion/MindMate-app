import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate/services/safety_ai_service.dart';
import 'package:mindmate/services/email_service.dart';

class RiskDetectionService {
  final SupabaseClient supabase;

  final int moodHistoryLimit;
  final int journalHistoryLimit;
  final int chatHistoryLimit;
  final double riskThreshold;
  final int notificationCooldownMinutes;

  RiskDetectionService(
    this.supabase, {
    this.moodHistoryLimit = 50,
    this.journalHistoryLimit = 10,
    this.chatHistoryLimit = 30,
    this.riskThreshold = 9.0,
    this.notificationCooldownMinutes = 1,
  });

  /// Fetch recent moods, journals, chats for user
  Future<Map<String, dynamic>> _fetchUserContext(String userId) async {
    print("🔹 Fetching user context for $userId ...");

    // fetch last_sent timestamp
    final notif = await supabase
        .from('user_notifications')
        .select('last_sent')
        .eq('user_id', userId)
        .maybeSingle();

    final lastSentUtc = notif != null && notif['last_sent'] != null
        ? DateTime.parse(notif['last_sent']).toUtc()
        : DateTime.fromMillisecondsSinceEpoch(0).toUtc();

    print("🕒 Filtering only new data after last_sent: $lastSentUtc");

    final lastSentPH = lastSentUtc.add(Duration(hours: 8));

    final moodsRes = await supabase
        .from('moods')
        .select()
        .eq('user_id', userId)
        .gt('created_at', lastSentPH.toIso8601String())
        .order('created_at', ascending: false)
        .limit(moodHistoryLimit);

    final journalsRes = await supabase
        .from('journals')
        .select()
        .eq('user_id', userId)
        .gt('created_at', lastSentUtc.toIso8601String())
        .order('created_at', ascending: false)
        .limit(journalHistoryLimit);

    final chatsRes = await supabase
        .from('chat_messages')
        .select()
        .eq('user_id', userId)
        .gt('created_at', lastSentUtc.toIso8601String())
        .order('created_at', ascending: false)
        .limit(chatHistoryLimit);

    print("🔹 New data: ${moodsRes.length} moods, "
          "${journalsRes.length} journals, ${chatsRes.length} chats.");

    return {
      "moods": List<Map<String, dynamic>>.from(moodsRes),
      "journals": List<Map<String, dynamic>>.from(journalsRes),
      "chats": List<Map<String, dynamic>>.from(chatsRes),
    };
  }

  /// Analyze risk using SafetyAIService (Edge Function)
  Future<Map<String, dynamic>> _analyzeRiskContext({
    required String userId,
    required String userName,
    required List<Map<String, dynamic>> moods,
    required List<Map<String, dynamic>> journals,
    required List<Map<String, dynamic>> chats,
  }) async {

     print("🔹 Analyzing risk for $userName ...");

    final aiResult = await SafetyAIService.analyzeRisk(
      userId: userId,
      userName: userName,
      moods: moods,
      journals: journals,
      chats: chats,
    );

    final score = (aiResult['riskScore'] as double?) ?? 0.0;
    final reason = aiResult['riskReason']?.toString() ?? "";

    print("🔹 AI Risk Analysis -> score: $score, reason: $reason");

    return {
      "riskScore": score,
      "riskReason": reason,
    };
  }

  /// Throttle emergency notifications to prevent spamming
  Future<bool> _canSendNotification(String userId) async {
    final nowUtc = DateTime.now().toUtc();

    final lastNotif = await supabase
        .from('user_notifications')
        .select('last_sent')
        .eq('user_id', userId)
        .maybeSingle();

    final lastSentUtc = lastNotif != null
      ? DateTime.tryParse(lastNotif['last_sent'])?.toUtc()
      : null;

    if (lastSentUtc != null) {
      final diffMinutes = nowUtc.difference(lastSentUtc).inMinutes;
      print("Device local time: ${DateTime.now()}");
      print("Device UTC time:   ${DateTime.now().toUtc()}");
      print("🕒 nowUtc=$nowUtc lastSentUtc=$lastSentUtc diffMinutes=$diffMinutes");
      if (diffMinutes < notificationCooldownMinutes) {
        print("⚠️ Notification skipped: cooldown active ($diffMinutes minutes since last sent)");
        return false;
      }
    }

    return true;
  }

  /// Send emergency notification email if allowed by cooldown
  Future<bool> _sendEmergencyNotification({
    required String userId,
    required String userName,
    required String contactEmail,
    required String riskReason,
  }) async {
    if (!await _canSendNotification(userId)) return false;

    try {
      await sendEmergencyEmail(
        contactEmail: contactEmail,
        userId: userId,
        riskReason: riskReason,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Public method: check risk + notify emergency contact if needed
  Future<void> detectAndNotifyMultiple({
  required String userId,
  required String userName,
  required List<String> emergencyEmails,
}) async {
  if (emergencyEmails.isEmpty) {
    print("⚠️ No emergency emails provided; skipping notification.");
    return;
  }

  print("⚠️ Running SafetyAI risk detection for $userName");

  final context = await _fetchUserContext(userId);

  final aiResult = await _analyzeRiskContext(
    userId: userId,
    userName: userName,
    moods: context['moods'] as List<Map<String, dynamic>>,
    journals: context['journals'] as List<Map<String, dynamic>>,
    chats: context['chats'] as List<Map<String, dynamic>>,
  );

  final score = aiResult['riskScore'] as double;
  final reason = aiResult['riskReason'] as String;

  print("ℹ️ SafetyAI: score=$score reason=$reason");

  if (score >= riskThreshold) {
    print("⚠️ Risk score ($score) >= threshold ($riskThreshold)");

    // <-- Declare the variable here
    bool atLeastOneSent = false;

    for (final email in emergencyEmails) {
      final sent = await _sendEmergencyNotification(
        userId: userId,
        userName: userName,
        contactEmail: email,
        riskReason: reason,
      );
      if (sent) {
        print("✅ Emergency email sent to $email");
        atLeastOneSent = true;
      } else {
        print("⚠️ Emergency email to $email skipped (cooldown or failed).");
      }
    }

    // Update last_sent only if at least one email was sent
    if (atLeastOneSent) {
      await supabase.from('user_notifications').upsert({
        'user_id': userId,
        'last_sent': DateTime.now().toUtc().toIso8601String(),
      },onConflict: 'user_id',);
      print("📝 Updated last_sent in user_notifications");
    }
  } else {
    print("✅ Risk score ($score) below threshold ($riskThreshold); no action taken.");
  }
}

}
