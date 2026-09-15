import 'package:flutter/material.dart';

import '../../models/candidate.dart';
import '../../models/voter.dart';
import 'slip_format_1.dart';
import 'slip_format_2.dart';
import 'slip_format_3.dart';

abstract class SlipTemplate {
  String get id;
  String get name;
  String get description;

  Widget buildSlip({
    required BuildContext context,
    required Candidate? candidate,
    required Voter voter,
    required String footerText,
    bool isRotated90 = true,
  });
}

// 🔴 ডায়নামিক রেজিস্ট্রি: ফরম্যাট ৩ স্বয়ংক্রিয়ভাবে যুক্ত হয়েছে
class SlipRegistry {
  static final List<SlipTemplate> templates = [
    SlipFormat1(),
    SlipFormat2(),
    SlipFormat3(), // 🔴 নতুন যুক্ত ফরম্যাট ৩ (প্রিমিয়াম ডিজিটাল ব্যাজ)
  ];

  static SlipTemplate getTemplate(String id) {
    return templates.firstWhere(
      (t) => t.id == id,
      orElse: () => templates.first,
    );
  }
}
