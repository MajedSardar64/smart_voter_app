import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OfflineImageService {
  static Future<String?> downloadAndCacheImage(
    String? imageUrl,
    String fileNamePrefix,
  ) async {
    if (kIsWeb) {
      return imageUrl;
    }

    if (imageUrl == null || imageUrl.trim().isEmpty) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final localFilePath =
          '${directory.path}/${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';

      final response = await http
          .get(
            Uri.parse(imageUrl),
            headers: {"ngrok-skip-browser-warning": "true"},
          )
          .timeout(const Duration(seconds: 4)); // 🔴 মাত্র ৪ সেকেন্ড টাইমআউট

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
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

        final file = File(localFilePath);
        await file.writeAsBytes(response.bodyBytes);
        return localFilePath;
      }
    } catch (e) {
      print('Image cache non-critical warning: $e');
    }
    return imageUrl;
  }
}
