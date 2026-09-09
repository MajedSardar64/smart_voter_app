import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../models/voter.dart';
import 'slips/slip_template.dart';

class VoterPrintSlip extends StatelessWidget {
  final Candidate? candidate;
  final Voter voter;
  final String footerText;
  final bool isRotated90;
  final String slipFormat;

  const VoterPrintSlip({
    super.key,
    required this.candidate,
    required this.voter,
    this.footerText = 'সরদার আইটি, ঢাকা, ০১৬xxxxxxxx',
    this.isRotated90 = true,
    this.slipFormat = 'format_1',
  });

  @override
  Widget build(BuildContext context) {
    // 🔴 রেজিস্ট্রি থেকে ডায়নামিকভাবে সংশ্লিষ্ট ফরম্যাট লোড করা
    final template = SlipRegistry.getTemplate(slipFormat);
    return template.buildSlip(
      context: context,
      candidate: candidate,
      voter: voter,
      footerText: footerText,
      isRotated90: isRotated90,
    );
  }
}
