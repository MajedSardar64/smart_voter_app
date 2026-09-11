import 'package:flutter/foundation.dart';

class AppConfig {
  static const bool isLiveApiMode = true;
  // আপনি টেস্ট করছেন বলে এটি false করা আছে। টেস্টিং শেষে true করে দেবেন:
  // static const bool blockDeveloperMode = true;

  static const String _defaultIpHost = "202.136.89.246:5051";
  static const String _apiEndpoint = "/VoterListApi/api-v1/app/api.php";

  // static const String _defaultIpHost = "voterlistapi.opik.net";
  // static const String _apiEndpoint = "/api-v1/app/api.php";

  // 🔴 ডায়নামিক API URL: http এবং https উভয় প্রোটোকলেই স্বয়ংক্রিয়ভাবে কাজ করবে
  static String get apiBaseUrl {
    if (kIsWeb) {
      final currentUri = Uri.base;
      // ব্রাউজার যে স্কিম (http বা https) দিয়ে খোলা হয়েছে, ঠিক সেটাই অটোমেটিক ধরবে
      final scheme = currentUri.scheme.isNotEmpty ? currentUri.scheme : 'http';

      // যদি একই সার্ভার/হোস্টে ওয়েবসাইট এবং এপিআই থাকে
      if (currentUri.host == '202.136.89.246') {
        final port = currentUri.hasPort ? ":${currentUri.port}" : "";
        return "$scheme://${currentUri.host}$port$_apiEndpoint";
      }

      // অন্য কোনো ডোমেন বা হোস্ট থেকে ওপেন হলেও একই স্কিম ম্যাচ করবে
      return "$scheme://$_defaultIpHost$_apiEndpoint";
    }

    // মোবাইল অ্যাপ্লিকেশনের জন্য ডিফল্ট লিংক
    return "http://$_defaultIpHost$_apiEndpoint";
  }
}
