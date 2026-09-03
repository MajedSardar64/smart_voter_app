import 'dart:convert';

import 'package:encrypt/encrypt.dart';

class SecurityHelper {
  // আপনার জেনারেট করা ৩২ ক্যারেক্টারের সিক্রেট কি (AES-256 Key)
  static const String _secretKey =
      "SmartVoterSecretKey2026Secure99X"; // ঠিক ৩২ অক্ষর
  static const String _secretIV = "VoterSecurityIV_"; // ঠিক ১৬ অক্ষর

  // ডাটাবেজের জন্য শক্তিশালী সিক্রেট কি
  static const String dbSecretKey = "VoterDBSecure@2026#AES256EncryptedKey!";

  static final _key = Key.fromUtf8(_secretKey);
  static final _iv = IV.fromUtf8(_secretIV);
  static final _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  // সম্পূর্ণ রিকোয়েস্ট বডি ১০০% এনক্রিপ্ট করা
  static String encryptWholeRequest(Map<String, dynamic> data) {
    try {
      final String jsonString = jsonEncode(data);
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
      return jsonEncode({"req": encrypted.base64});
    } catch (e) {
      return jsonEncode(data);
    }
  }

  // সার্ভার থেকে আসা ১০০% এনক্রিপ্টেড রেসপন্স সম্পূর্ণ ডিক্রিপ্ট করা
  static dynamic decryptWholeResponse(String responseBody) {
    try {
      final Map<String, dynamic> bodyJson = jsonDecode(responseBody);
      if (bodyJson.containsKey('enc')) {
        final String cipherBase64 = bodyJson['enc'];
        final decryptedJsonStr = _encrypter.decrypt64(cipherBase64, iv: _iv);
        return jsonDecode(decryptedJsonStr);
      }
      return bodyJson;
    } catch (e) {
      print("Decryption Error: $e");
      return null;
    }
  }
}
