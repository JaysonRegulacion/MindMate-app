package com.example.mindmate

import android.app.PendingIntent
import android.content.Intent
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "sms_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                if (call.method == "sendSms") {

                    val number = call.argument<String>("number")
                    val message = call.argument<String>("message")

                    try {

                        // 🔥 STEP 1: SIM CHECK
                        val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager

                        when (tm.simState) {
                            TelephonyManager.SIM_STATE_ABSENT -> {
                                println("📵 NO SIM CARD DETECTED")
                                result.success(
                                    mapOf("sim" to "NO_SIM", "status" to "FAILED")
                                )
                                return@setMethodCallHandler
                            }

                            TelephonyManager.SIM_STATE_PIN_REQUIRED,
                            TelephonyManager.SIM_STATE_PUK_REQUIRED,
                            TelephonyManager.SIM_STATE_UNKNOWN -> {
                                println("🔐 SIM NOT READY")
                                result.success(
                                    mapOf("sim" to "NOT_READY", "status" to "FAILED")
                                )
                                return@setMethodCallHandler
                            }

                            TelephonyManager.SIM_STATE_READY -> {
                                println("📶 SIM READY")
                            }
                        }

                        // 🔥 STEP 2: SEND SMS
                        val smsManager = SmsManager.getDefault()

                        val sentPI = PendingIntent.getBroadcast(
                            applicationContext,
                            0,
                            Intent("SMS_SENT"),
                            PendingIntent.FLAG_IMMUTABLE
                        )

                        val deliveredPI = PendingIntent.getBroadcast(
                            applicationContext,
                            0,
                            Intent("SMS_DELIVERED"),
                            PendingIntent.FLAG_IMMUTABLE
                        )

                        smsManager.sendTextMessage(
                            number,
                            null,
                            message,
                            sentPI,
                            deliveredPI
                        )

                        result.success(
                            mapOf("sim" to "READY", "status" to "SMS_SENT")
                        )

                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.message, null)
                    }

                } else {
                    result.notImplemented()
                }
            }
    }
}