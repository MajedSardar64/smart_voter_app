import 'package:flutter/material.dart';

import '../../models/candidate.dart';
import '../../models/voter.dart';
import 'slip_format_1.dart';
import 'slip_format_2.dart';

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

// 🔴 ডায়নামিক রেজিস্ট্রি: নতুন কোনো ফরম্যাট তৈরি করলে শুধু এই লিস্টে একটি লাইন যোগ করলেই হবে
class SlipRegistry {
  static final List<SlipTemplate> templates = [
    SlipFormat1(),
    SlipFormat2(),
    // ভবিষ্যতে ফরম্যাট ৩ তৈরি করলে শুধু: SlipFormat3(), লিখলেই সেটিংসে নিজে থেকে আসবে
  ];

  static SlipTemplate getTemplate(String id) {
    return templates.firstWhere(
      (t) => t.id == id,
      orElse: () => templates.first,
    );
  }
}
