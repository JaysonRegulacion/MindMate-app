import 'package:flutter/services.dart';

class SMSService {
  static const MethodChannel _channel = MethodChannel('sms_channel');

  static Future<void> sendEmergencySMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod('sendSms', {
        'number': phoneNumber,
        'message': message,
      });

      if (result['sim'] == 'NO_SIM') {
        print("📵 No SIM detected BEFORE sending SMS result");
        return;
      }

      print("📤 SMS result: ${result['status']}");
    } catch (e) {
      print("❌ SMS failed: $e");
      throw Exception("SMS failed: $e");
    }
  }
}