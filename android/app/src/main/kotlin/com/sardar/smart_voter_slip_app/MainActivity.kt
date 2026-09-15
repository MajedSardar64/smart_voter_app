package com.sardar.smart_voter_slip_app

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.smart_voter_app/bengali_ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // 🔴 মাদারবোর্ডের অপরিবর্তনীয় স্থায়ী হার্ডওয়্যার আইডি (ডাটা ক্লিয়ার বা আনইনস্টল করলেও একই থাকবে)
                "getAndroidHardwareId" -> {
                    try {
                        val androidId: String? = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        if (androidId != null && androidId.isNotEmpty()) {
                            result.success(androidId)
                        } else {
                            result.success("UNKNOWN_ANDROID")
                        }
                    } catch (e: Exception) {
                        result.success("UNKNOWN_ANDROID")
                    }
                }
                // NID স্ক্যানার বা অন্যান্য কোনো মেথড থাকলে তা অক্ষুণ্ণ রাখা
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}