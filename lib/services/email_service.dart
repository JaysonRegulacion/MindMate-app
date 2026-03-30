import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Fetch user's full name from the database
Future<String> getUserFullName(String userId) async {
  final response = await supabase
      .from('profiles') 
      .select('first_name, last_name')
      .eq('id', userId)
      .maybeSingle();

  if (response == null) return "A MindMate user";

  final firstName = response['first_name'] as String? ?? '';
  final lastName = response['last_name'] as String? ?? '';

  final fullName = '$firstName $lastName'.trim();
  return fullName.isEmpty ? "A MindMate user" : fullName;
}

/// Send emergency email using full name automatically
Future<void> sendEmergencyEmail({
  required String contactEmail,
  required String riskReason,
  required String userId,
}) async {
  final userName = await getUserFullName(userId);

  final url = Uri.parse(
    'https://jvvesomjnzzjzakxcdmj.supabase.co/functions/v1/send-emergency-email',
  );

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2dmVzb21qbnp6anpha3hjZG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MTg2ODAsImV4cCI6MjA3MDQ5NDY4MH0.jXb1RM7NlsrLiGuqJCZxkVp6eMD0w0XxX5FM85l5KqY',
    },
    body: jsonEncode({
      'contactEmail': contactEmail,
      'userName': userName,
      'riskReason': riskReason,
    }),
  );

  if (response.statusCode == 200) {
    print("📧 Emergency email sent successfully.");
  } else {
    print("❌ Failed to send email: ${response.body}");
  }
}



// // services/email_service.dart
// import 'package:mailer/mailer.dart';
// import 'package:mailer/smtp_server.dart';

// Future<void> sendEmergencyEmail({
//   required String contactEmail,
//   required String userName,
//   required String riskReason,
// }) async {
//   const gmailUser = 'jaysoninchrist@gmail.com';
//   const appPassword = 'momccgqnspwrbsab';

//   final smtpServer = gmail(gmailUser, appPassword);

//   final message = Message()
//     ..from = Address(gmailUser, 'MindMate Alert')
//     ..recipients.add(contactEmail)
//     ..subject = 'MindMate Emergency Alert for $userName'
//     ..text = 'High-risk activity detected for $userName.\n\nReason:\n$riskReason';

//   try {
//     final sendReport = await send(message, smtpServer);
//     print('Emergency email sent: ${sendReport.toString()}');
//   } catch (e) {
//     print('Failed to send emergency email: $e');
//   }
// }
