import 'dart:convert';

import 'package:encrypt/encrypt.dart';

class SecurityHelper {
  // পিএইচপি এর সাথে মেলানো ঠিক ৩২ ও ১৬ ক্যারেক্টারের সিক্রেট কি
  static const String _secretKey =
      "SmartVoterSecretKey2026Secure99X"; // ৩২ অক্ষর
  static const String _secretIV = "VoterSecurityIV_"; // ঠিক ১৬ অক্ষর

  static final _key = Key.fromUtf8(_secretKey);
  static final _iv = IV.fromUtf8(_secretIV);
  static final _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  // ডাটা এনক্রিপ্ট করা
  static String encryptPayload(dynamic data) {
    try {
      final String jsonString = jsonEncode(data);
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return jsonEncode(data);
    }
  }

  // ডাটা ডিক্রিপ্ট করা
  static dynamic decryptPayload(String encryptedBase64) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedBase64, iv: _iv);
      return jsonDecode(decrypted);
    } catch (e) {
      return jsonDecode(encryptedBase64);
    }
  }
}
