import 'dart:io';
import 'dart:ui' as ui;

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

      // হাই কোয়ালিটি ইমেজ রেন্ডারিং (pixelRatio: 3.0)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/voter_slip_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '$voterName - এর নির্বাচনী ভোটার তথ্য স্লিপ');
    } catch (e) {
      print('Slip Share Error: $e');
    }
  }
}
