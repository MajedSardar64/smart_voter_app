import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/candidate.dart';
import '../../models/voter.dart';
import '../../utils/bangla_helper.dart';
import 'slip_template.dart';

class SlipFormat1 implements SlipTemplate {
  @override
  String get id => 'format_1';

  @override
  String get name => 'ফরম্যাট ১ (স্ট্যান্ডার্ড ক্লাসিক)';

  @override
  String get description =>
      'ছবি ও মার্কার সমন্বয়ে জনপ্রিয় নির্বাচনী স্ট্যান্ডার্ড ডিজাইন';

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
      padding: const EdgeInsets.symmetric(vertical: 0.8),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Bangla',
            fontSize: 12.5,
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

    // 🔴 মোট প্রস্থ ৫০০ পিক্সেলের মধ্যে নিখুঁতভাবে নির্ধারিত (৪ পিক্সেল ওভারফ্লো দূরীকরণ)
    // প্যাডিং: ৮ পিক্সেল (৪+৪)। বাম বক্স: ২১২, স্পেসার: ৬, ডান বক্স: ২৭৪ = ৪৯২ + ৮ = ৫০০ পিক্সেল ফিক্সড।
    Widget slipContent = Container(
      width: 500,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // বাম পাশের প্রার্থীর কার্ড (উইডথ: ২১২)
              Container(
                width: 212,
                height: 232,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          candidate?.electionTitle ?? 'নির্বাচন',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Bangla',
                            fontSize: 12,
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
                            fontSize: 12,
                            color: Colors.black,
                            height: 1.15,
                          ),
                        ),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontFamily: 'Bangla',
                              height: 1.2,
                            ),
                            children: [
                              TextSpan(
                                text: '${candidate?.name ?? ""} ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const TextSpan(text: 'কে\n'),
                              TextSpan(
                                text: '${candidate?.symbolName ?? ""} মার্কায় ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                          width: 118,
                          height: 108,
                          child: _buildImage(
                            candidate?.candidateImage,
                            width: 118,
                            height: 108,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 74,
                          height: 108,
                          child: _buildSymbolImage(
                            candidate?.symbolImage,
                            width: 74,
                            height: 108,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // ডান পাশের ভোটারের তথ্য (উইডথ: ২৭৪)
              Container(
                width: 274,
                height: 232,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Padding(
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
                            fontSize: 12,
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
                          fontSize: 11,
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
                      _printLine('ওয়ার্ড নং: ', banglaWard),
                      if (voter.publicationDate.isNotEmpty)
                        _printLine(
                          'তালিকা প্রকাশঃ ',
                          BanglaHelper.toBanglaDigits(voter.publicationDate),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 🔴 ফুটার: অপ্রয়োজনীয় "ফরম্যাট ১" লেখা বাদ দেওয়া হয়েছে
          Container(
            width: 492,
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              footerText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Bangla',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
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
