import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SlipShareHelper {
  static Future<void> captureAndShareSlip(
    GlobalKey boundaryKey,
    String voterName,
  ) async {
    try {
      RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final fileName =
          'voter_slip_${DateTime.now().millisecondsSinceEpoch}.png';

      // 🔴 ওয়েব ব্রাউজারের ক্ষেত্রে XFile.fromData ব্যবহার করা যাতে কোনো ফাইল পাথ এরর না দেয়
      if (kIsWeb) {
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: fileName,
        );
        await Share.shareXFiles([
          xFile,
        ], text: '$voterName - এর নির্বাচনী ভোটার তথ্য স্লিপ');
        return;
      }

      // মোবাইল ডিভাইসে ফাইল হিসেবে সেভ করে শেয়ার
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '$voterName - এর নির্বাচনী ভোটার তথ্য স্লিপ');
    } catch (e) {
      print('Slip Share Error: $e');
    }
  }
}
