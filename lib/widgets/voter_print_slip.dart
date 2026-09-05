import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../models/voter.dart';
import '../utils/bangla_helper.dart';

class VoterPrintSlip extends StatelessWidget {
  final Candidate? candidate;
  final Voter voter;
  final String footerText;
  final bool isRotated90;

  const VoterPrintSlip({
    super.key,
    required this.candidate,
    required this.voter,
    this.footerText = 'সরদার আইটি, ঢাকা, ০১৬১৯০৯৭৫৭১',
    this.isRotated90 = true,
  });

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
            size: width != null ? width / 2 : 40,
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
            size: width != null ? width / 2 : 40,
            color: Colors.black54,
          ),
        );
      }
    }
    return Icon(
      Icons.person,
      size: width != null ? width / 2 : 40,
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
            size: width != null ? width / 2 : 40,
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
            size: width != null ? width / 2 : 40,
            color: Colors.black87,
          ),
        );
      }
    }
    return Icon(
      Icons.lock,
      size: width != null ? width / 2 : 40,
      color: Colors.black87,
    );
  }

  Widget _printLine(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Bangla',
            fontSize: 13,
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
  Widget build(BuildContext context) {
    String banglaDob = BanglaHelper.formatDobToBangla(voter.dob);
    String banglaSerial = BanglaHelper.toBanglaDigits(voter.serialNo);
    String banglaVoterNo = BanglaHelper.toBanglaDigits(voter.voterNo);

    final bool canShowCenter =
        candidate?.showPollingCenter != false &&
        voter.centerName.isNotEmpty &&
        voter.centerName != 'অনির্ধারিত কেন্দ্র';

    final boothsStr = voter.boothsCount.isNotEmpty
        ? " [বুথ: ${BanglaHelper.toBanglaDigits(voter.boothsCount)}]"
        : "";

    Widget slipContent = Container(
      width: 500,
      color: Colors.white,
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          candidate?.electionTitle ?? 'নির্বাচন ২০২৪',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Bangla',
                            fontSize: 13,
                            color: Colors.black,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          candidate?.postTitle ?? 'পদপ্রার্থী',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Bangla',
                            fontSize: 13,
                            color: Colors.black,
                            height: 1.15,
                          ),
                        ),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: 'Bangla',
                              height: 1.2,
                            ),
                            children: [
                              TextSpan(
                                text: '${candidate?.name ?? ""} ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const TextSpan(text: 'কে\n'),
                              TextSpan(
                                text: '${candidate?.symbolName ?? ""} মার্কায় ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const TextSpan(text: 'ভোট দিন'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 125,
                          height: 110,
                          child: _buildImage(
                            candidate?.candidateImage,
                            width: 125,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 70,
                          height: 110,
                          child: _buildSymbolImage(
                            candidate?.symbolImage,
                            width: 70,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              Container(
                width: 265,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Stack(
                  children: [
                    if (candidate?.symbolImage != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.15,
                          child: Center(
                            child: _buildSymbolImage(
                              candidate?.symbolImage,
                              width: 130,
                              height: 130,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canShowCenter)
                            Text(
                              'কেন্দ্রঃ ${voter.centerName}$boothsStr',
                              style: const TextStyle(
                                fontFamily: 'Bangla',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            'এলাকাঃ ${voter.area}',
                            style: const TextStyle(
                              fontFamily: 'Bangla',
                              fontSize: 11.5,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(
                            color: Colors.black,
                            thickness: 1,
                            height: 4,
                          ),
                          _printLine(
                            '$banglaSerial. নামঃ ',
                            voter.name,
                            isBold: true,
                          ),
                          _printLine('ভোটার নং: ', banglaVoterNo),
                          _printLine('জন্মঃ ', banglaDob),
                          _printLine('পিতা/স্বামী: ', voter.fatherOrHusband),
                          _printLine('মাতাঃ ', voter.mother),
                          _printLine('ঠিকানাঃ ', voter.address),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Container(
            width: 500,
            padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  footerText,
                  style: const TextStyle(
                    fontFamily: 'Bangla',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Text(
                  'স্মার্ট ভোটার স্লিপ',
                  style: TextStyle(
                    fontFamily: 'Bangla',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isRotated90) {
      return RotatedBox(quarterTurns: 1, child: slipContent);
    }
    return slipContent;
  }
}
