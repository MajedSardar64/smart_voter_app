import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OfflineImageService {
  static Future<String?> downloadAndCacheImage(
    String? imageUrl,
    String fileNamePrefix,
  ) async {
    // 🔴 ওয়েব ব্রাউজারে লোকাল ফাইল সিস্টেম থাকে না, তাই সরাসরি ছবির URL রিটার্ন করবে (ক্র্যাশ রোধ)
    if (kIsWeb) {
      return imageUrl;
    }

    if (imageUrl == null || imageUrl.trim().isEmpty) return null;

    try {
      // ১. মেমোরি থেকে আগের ইমেজ ক্যাশ ক্লিয়ার করা
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final directory = await getApplicationDocumentsDirectory();
      final localFilePath =
          '${directory.path}/${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';

      // ২. আগের পুরনো ফাইল ডিলিট করা
      final dir = Directory(directory.path);
      if (dir.existsSync()) {
        for (var f in dir.listSync()) {
          if (f is File && f.path.contains(fileNamePrefix)) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      }

      // ৩. নতুন ছবি ডাউনলোড ও অফলাইনে সেভ করা
      final response = await http
          .get(
            Uri.parse(imageUrl),
            headers: {"ngrok-skip-browser-warning": "true"},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final file = File(localFilePath);
        await file.writeAsBytes(response.bodyBytes);

        PaintingBinding.instance.imageCache.clear();
        return localFilePath; // মোবাইলের জন্য অফলাইন লোকাল ফাইল পাথ
      }
    } catch (e) {
      print('Image cache error for $fileNamePrefix: $e');
    }
    return imageUrl;
  }
}
