import 'package:flutter/material.dart';

import '../config/app_config.dart';
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
    this.footerText = '',
    this.isRotated90 = true,
    this.slipFormat = 'format_1',
  });

  @override
  Widget build(BuildContext context) {
    // 🔴 সক্রিয় কোম্পানির ফুটার টেক্সট সরাসরি লোড হবে
    final effectiveFooter = footerText.trim().isNotEmpty
        ? footerText
        : AppConfig.thermalFooterInfo;

    final template = SlipRegistry.getTemplate(slipFormat);
    return template.buildSlip(
      context: context,
      candidate: candidate,
      voter: voter,
      footerText: effectiveFooter,
      isRotated90: isRotated90,
    );
  }
}
