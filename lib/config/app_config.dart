import 'package:flutter/foundation.dart';

class AppConfig {
  static const bool isLiveApiMode = true;

  // 🔴 লাইভ ও লোকাল সার্ভার হোস্ট
  static const String _liveHost = "202.136.89.246:5051";
  static const String _localHost = "10.0.2.2:5051";
  static const String _apiEndpoint = "/VoterListApi/api-v1/app/api.php";

  // =========================================================================
  // 🏢 কোম্পানির প্রাথমিক তথ্য (শুধুমাত্র এইখানে একবার পরিবর্তন করবেন)
  // =========================================================================
  static const String companyName = 'সরদার আইটি';
  static const String companyCity = 'ঢাকা';
  static const String helplineNumber = '০১৬xxxxxxxx';
  static const String companyWebsite = 'আপাতত নেই';
  static const String developerName = 'সরদার';
  static const String copyrightYears = '২০২৪-২০২৬';
  static const String appName = 'স্মার্ট ভোটার ইনফো';

  // =========================================================================
  // ⚡ কম্পাইল-টাইম কনস্ট্যান্ট (কনস্ট্রাক্টরে সরাসরি ব্যবহারযোগ্য Const String)
  // =========================================================================
  static const String companyAddress = '$companyCity, বাংলাদেশ';
  static const String loginCompanyText = companyName;
  static const String loginHelplineText = 'হেল্পলাইন: $helplineNumber';
  static const String softwareFooterInfo =
      '$companyName, $companyCity। মোবাইল: $helplineNumber';
  static const String thermalFooterInfo =
      '$companyName, $companyCity, $helplineNumber';
  static const String copyrightText =
      'স্বত্ব © $copyrightYears $companyName। সর্বস্বত্ব সংরক্ষিত।';

  // 🔴 নির্বাচন শেষ সংক্রান্ত বার্তা
  static const String electionClosedNotice =
      'নির্বাচন সম্পন্ন হওয়ায় সাময়িকভাবে এই সার্ভিসটি বন্ধ রয়েছে। বিস্তারিত তথ্যের জন্য অ্যাডমিনের সাথে যোগাযোগ করুন।';

  // 🔴 ফোন ডায়াল করার জন্য ইংরেজি ডিজিটের হেল্পলাইন
  static String get rawHelplineNumber => helplineNumber
      .replaceAll('০', '0')
      .replaceAll('১', '1')
      .replaceAll('২', '2')
      .replaceAll('৩', '3')
      .replaceAll('৪', '4')
      .replaceAll('৫', '5')
      .replaceAll('৬', '6')
      .replaceAll('৭', '7')
      .replaceAll('৮', '8')
      .replaceAll('৯', '9')
      .replaceAll('x', '-');

  // 🔴 ঢাকা টাইমজোন (UTC +6 ঘণ্টা)
  static DateTime get dhakaNow {
    return DateTime.now().toUtc().add(const Duration(hours: 6));
  }

  // 🔴 ডায়নামিক API URL (http / https উভয় প্রোটোকল সাপোর্ট)
  static String get apiBaseUrl {
    if (kIsWeb) {
      final currentUri = Uri.base;
      final scheme = currentUri.scheme.isNotEmpty ? currentUri.scheme : 'http';

      if (currentUri.host == 'localhost' ||
          currentUri.host == '127.0.0.1' ||
          currentUri.host.startsWith('192.168.')) {
        final port = currentUri.hasPort ? ":${currentUri.port}" : "";
        return "$scheme://${currentUri.host}$port$_apiEndpoint";
      }

      if (currentUri.host == '202.136.89.246') {
        final port = currentUri.hasPort ? ":${currentUri.port}" : "";
        return "$scheme://${currentUri.host}$port$_apiEndpoint";
      }

      return "$scheme://${currentUri.host}${currentUri.hasPort ? ":${currentUri.port}" : ""}$_apiEndpoint";
    }

    final targetHost = isLiveApiMode ? _liveHost : _localHost;

    if (targetHost.startsWith('http://') || targetHost.startsWith('https://')) {
      return "$targetHost$_apiEndpoint";
    }

    return "http://$targetHost$_apiEndpoint";
  }
}
