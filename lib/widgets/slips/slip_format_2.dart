import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/candidate.dart';
import '../../models/voter.dart';
import '../../utils/bangla_helper.dart';
import 'slip_template.dart';

class SlipFormat2 implements SlipTemplate {
  @override
  String get id => 'format_2';

  @override
  String get name => 'ফরম্যাট ২ (প্রফেশনাল বক্সড)';

  @override
  String get description =>
      'বর্ডার ও টেবিল স্টাইলে সুবিন্যস্ত আধুনিক বক্সড স্লিপ';

  Widget _buildImage(
    String? path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: width != null ? width / 2 : 36,
            color: Colors.black54,
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: width != null ? width / 2 : 36,
            color: Colors.black54,
          ),
        );
      }
    }
    return Icon(
      Icons.person,
      size: width != null ? width / 2 : 36,
      color: Colors.black54,
    );
  }

  Widget _buildSymbolImage(
    String? path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.how_to_vote,
            size: width != null ? width / 2 : 36,
            color: Colors.black87,
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.how_to_vote,
            size: width != null ? width / 2 : 36,
            color: Colors.black87,
          ),
        );
      }
    }
    return Icon(
      Icons.lock,
      size: width != null ? width / 2 : 36,
      color: Colors.black87,
    );
  }

  Widget _printLine(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.8),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Bangla',
            fontSize: 12,
            color: Colors.black,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            height: 1.15,
          ),
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildSlip({
    required BuildContext context,
    required Candidate? candidate,
    required Voter voter,
    required String footerText,
    bool isRotated90 = true,
  }) {
    String banglaDob = BanglaHelper.formatDobToBangla(voter.dob);
    String banglaSerial = BanglaHelper.toBanglaDigits(voter.serialNo);
    String banglaVoterNo = BanglaHelper.toBanglaDigits(voter.voterNo);
    String banglaWard = BanglaHelper.toBanglaDigits(voter.displayWard);

    final bool canShowCenter =
        candidate?.showPollingCenter != false &&
        voter.centerName.isNotEmpty &&
        voter.centerName != 'অনির্ধারিত কেন্দ্র';

    final boothsStr = voter.boothsCount.isNotEmpty
        ? " [বুথ: ${BanglaHelper.toBanglaDigits(voter.boothsCount)}]"
        : "";

    Widget slipContent = Container(
      width: 500, // ফিক্সড থার্মাল প্রস্থ
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // হেডার
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 1.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    candidate?.electionTitle ?? 'নির্বাচনী ভোটার স্লিপ',
                    style: const TextStyle(
                      fontFamily: 'Bangla',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (candidate?.electionDate != null &&
                      candidate!.electionDate.isNotEmpty)
                    Text(
                      'তারিখ: ${candidate!.electionDate}',
                      style: const TextStyle(
                        fontFamily: 'Bangla',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),

            // মূল কন্টেন্ট
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canShowCenter)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(3),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            border: Border.all(color: Colors.black54),
                          ),
                          child: Text(
                            'ভোট কেন্দ্রঃ ${voter.centerName}$boothsStr',
                            style: const TextStyle(
                              fontFamily: 'Bangla',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      _printLine('ভোটার ক্রমিকঃ ', banglaSerial, isBold: true),
                      _printLine('ভোটার নামঃ ', voter.name, isBold: true),
                      _printLine('ভোটার নম্বরঃ ', banglaVoterNo),
                      _printLine('জন্ম তারিখঃ ', banglaDob),
                      _printLine('পিতা/স্বামীঃ ', voter.fatherOrHusband),
                      _printLine('মাতাঃ ', voter.mother),
                      _printLine('ঠিকানাঃ ', voter.address),
                      _printLine('ভোটার এলাকাঃ ', voter.area),
                      _printLine('ওয়ার্ড নংঃ ', banglaWard),
                      if (voter.publicationDate.isNotEmpty)
                        _printLine(
                          'তালিকা প্রকাশঃ ',
                          BanglaHelper.toBanglaDigits(voter.publicationDate),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // প্রার্থীর ছবি ও মার্কা বক্স
                Container(
                  width: 140,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87, width: 1.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${candidate?.name ?? ""}\n(${candidate?.symbolName ?? ""} মার্কা)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Bangla',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildImage(
                            candidate?.candidateImage,
                            width: 66,
                            height: 78,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 2),
                          _buildSymbolImage(
                            candidate?.symbolImage,
                            width: 58,
                            height: 78,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${candidate?.symbolName ?? ""} মার্কায় ভোট দিন',
                        style: const TextStyle(
                          fontFamily: 'Bangla',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),

            // ফুটার
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Text(
                footerText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Bangla',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isRotated90) {
      return RotatedBox(quarterTurns: 1, child: slipContent);
    }
    return slipContent;
  }
}
