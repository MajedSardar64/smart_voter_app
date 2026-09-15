import 'package:flutter/foundation.dart';

// 🔴 প্রতিটি কোম্পানির প্রোফাইল মডেল
class CompanyProfile {
  final String companyName;
  final String companyCity;
  final String helplineNumber;
  final String companyWebsite;
  final String developerName;
  final String copyrightYears;

  const CompanyProfile({
    required this.companyName,
    required this.companyCity,
    required this.helplineNumber,
    this.companyWebsite = 'আপাতত নেই',
    this.developerName = 'সরদার',
    this.copyrightYears = '২০২৪-২০২৮',
  });
}

class AppConfig {
  static const bool isLiveApiMode = true;

  // 🔴 লাইভ ও লোকাল সার্ভার হোস্ট
  static const String _liveHost = "202.136.89.246:5051";
  static const String _localHost = "10.0.2.2:5051";
  static const String _apiEndpoint = "/VoterListApi/api-v1/app/api.php";

  // =========================================================================
  // 🎯 ১. বর্তমানে কোন প্রোফাইলটি ডিফল্ট/সক্রিয় থাকবে?
  // শুধুমাত্র নিচের নামটি পরিবর্তন করবেন (যেমন: 'sardar_it' অথবা 'smart_it' ইত্যাদি)
  // =========================================================================
  static const String activeProfile = 'sardar_it';

  // =========================================================================
  // 🏢 ২. একাধিক কোম্পানির প্রোফাইল তালিকা
  // এখানে আপনি ইচ্ছামতো যত খুশি কোম্পানির প্রোফাইল যোগ করে রাখতে পারবেন
  // =========================================================================
  static const Map<String, CompanyProfile> companyProfiles = {
    // প্রোফাইল ১: সরদার আইটি
    'sardar_it': CompanyProfile(
      companyName: 'সরদার আইটি',
      companyCity: 'ঢাকা',
      helplineNumber: '০১৬xxxxxxxx',
      companyWebsite: 'আপাতত নেই',
      developerName: 'সরদার',
      copyrightYears: '২০২৪-২০২৭',
    ),

    // প্রোফাইল ২: উদাহরণ কোম্পানি (প্রয়োজনে তথ্য পরিবর্তন করুন)
    'smart_tech': CompanyProfile(
      companyName: 'স্মার্ট টেক সল্যুশন',
      companyCity: 'চট্টগ্রাম',
      helplineNumber: '০১৭১১০০০০০০',
      companyWebsite: 'www.smarttech.com',
      developerName: 'ইঞ্জি. কাওসার',
      copyrightYears: '২০২৬',
    ),

    // প্রোফাইল ৩: অন্য যেকোনো কোম্পানি
    'election_care': CompanyProfile(
      companyName: 'ইলেকশন কেয়ার বাংলাদেশ',
      companyCity: 'সিলেট',
      helplineNumber: '০১৮২২০০০০০০',
      companyWebsite: 'www.electioncare.com.bd',
      developerName: 'আইটি টিম',
      copyrightYears: '২০২৬-২০২৬',
    ),
  };

  // =========================================================================
  // ⚡ ৩. সক্রিয় প্রোফাইল রিডার (নিজে থেকেই সিলেক্টেড কোম্পানির ডাটা লোড করবে)
  // =========================================================================
  static CompanyProfile get current =>
      companyProfiles[activeProfile] ?? companyProfiles.values.first;

  // পুরো অ্যাপে স্বয়ংক্রিয়ভাবে বর্তমান কোম্পানির তথ্য সরবরাহের গেটারসমূহ
  static const String appName = 'স্মার্ট ভোটার ইনফো';
  static String get companyName => current.companyName;
  static String get companyCity => current.companyCity;
  static String get helplineNumber => current.helplineNumber;
  static String get companyWebsite => current.companyWebsite;
  static String get developerName => current.developerName;
  static String get copyrightYears => current.copyrightYears;

  static String get companyAddress => '${current.companyCity}, বাংলাদেশ';
  static String get loginCompanyText => current.companyName;
  static String get loginHelplineText => 'হেল্পলাইন: ${current.helplineNumber}';
  static String get softwareFooterInfo =>
      '${current.companyName}, ${current.companyCity}। মোবাইল: ${current.helplineNumber}';
  static String get thermalFooterInfo =>
      '${current.companyName}, ${current.companyCity}, ${current.helplineNumber}';
  static String get copyrightText =>
      'স্বত্ব © ${current.copyrightYears} ${current.companyName}। সর্বস্বত্ব সংরক্ষিত।';

  // ফোন কল করার উপযোগী ইংরেজি ডিজিটের মোবাইল নম্বর
  static String get rawHelplineNumber => current.helplineNumber
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

  // 🔴 নির্বাচন শেষ সংক্রান্ত বার্তা
  static const String electionClosedNotice =
      'নির্বাচন সম্পন্ন হওয়ায় সাময়িকভাবে এই সার্ভিসটি বন্ধ রয়েছে। বিস্তারিত তথ্যের জন্য অ্যাডমিনের সাথে যোগাযোগ করুন।';

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
