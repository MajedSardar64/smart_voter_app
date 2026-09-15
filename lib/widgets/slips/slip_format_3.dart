import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/candidate.dart';
import '../../models/voter.dart';
import '../../utils/bangla_helper.dart';
import 'slip_template.dart';

class SlipFormat3 implements SlipTemplate {
  @override
  String get id => 'format_3';

  @override
  String get name => 'ফরম্যাট ৩ (প্রিমিয়াম ডিজিটাল ব্যাজ)';

  @override
  String get description =>
      'সলিড ব্ল্যাক ব্যাজ, ডাবল ফ্রেম ও আধুনিক টিকেট স্টাইল ক্রিয়েটিভ ডিজাইন';

  Widget _buildCandidateImage(
    String? path, {
    double width = 90,
    double height = 95,
  }) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.person, size: width * 0.5, color: Colors.black),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.person, size: width * 0.5, color: Colors.black),
        );
      }
    }
    return Icon(Icons.person, size: width * 0.5, color: Colors.black);
  }

  Widget _buildSymbolImage(
    String? path, {
    double width = 60,
    double height = 65,
  }) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              Icon(Icons.how_to_vote, size: width * 0.6, color: Colors.black),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              Icon(Icons.how_to_vote, size: width * 0.6, color: Colors.black),
        );
      }
    }
    return Icon(Icons.how_to_vote, size: width * 0.6, color: Colors.black);
  }

  Widget _infoRow(String label, String value, {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Bangla',
              fontSize: isLarge ? 12.5 : 11.5,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.15,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Bangla',
                fontSize: isLarge ? 13 : 11.5,
                fontWeight: isLarge ? FontWeight.bold : FontWeight.w600,
                color: Colors.black87,
                height: 1.15,
              ),
            ),
          ),
        ],
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
        ? " (বুথ: ${BanglaHelper.toBanglaDigits(voter.boothsCount)})"
        : "";

    final effectiveFooter = footerText.isNotEmpty
        ? footerText
        : AppConfig.thermalFooterInfo;

    // 🔴 মোট প্রস্থ ফিক্সড ৫০০ পিক্সেল (প্যাডিং ৮ + ভেতরের অংশ ৪৯২ = ৫০০)
    Widget slipContent = Container(
      width: 500,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ১. টপ হেডার ব্যানার (ইনভার্টেড সলিড ব্ল্যাক ব্যাজ)
          Container(
            width: 492,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '★ ${candidate?.electionTitle ?? "নির্বাচন ২০২৬"} ★',
                  style: const TextStyle(
                    fontFamily: 'Bangla',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (candidate?.electionDate != null &&
                    candidate!.electionDate.isNotEmpty)
                  Text(
                    'তারিখ: ${candidate.electionDate}',
                    style: const TextStyle(
                      fontFamily: 'Bangla',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ২. মিডল সেকশন (বাম পাশে প্রার্থীর মার্কা কার্ড + ডান পাশে ভোটারের ডিজিটাল পাস)
          SizedBox(
            width: 492,
            height: 228,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔴 বাম পাশের প্রার্থীর ক্রিয়েটিভ কার্ড (উইডথ: ১৯৪)
                Container(
                  width: 194,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // পদের শিরোনাম ব্যাজ
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          candidate?.postTitle ?? 'পদপ্রার্থী',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Bangla',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      // ছবি ও মার্কার ফ্রেম
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 104,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.black,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: _buildCandidateImage(
                                candidate?.candidateImage,
                                width: 96,
                                height: 104,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 76,
                                height: 72,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _buildSymbolImage(
                                  candidate?.symbolImage,
                                  width: 70,
                                  height: 66,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 76,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                color: Colors.black,
                                child: Text(
                                  candidate?.symbolName ?? 'মার্কা',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Bangla',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // প্রার্থীর ভোট আহ্বান
                      Column(
                        children: [
                          Text(
                            '${candidate?.name ?? ""} কে',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Bangla',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${candidate?.symbolName ?? ""} মার্কায় ভোট দিন',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Bangla',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // 🔴 ডান পাশের ভোটারের ডিজিটাল পাস (উইডথ: ২৯২)
                Container(
                  width: 292,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // কেন্দ্র ও ক্রমিক নম্বর হাইলাইট বক্স
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ক্রমিকঃ $banglaSerial',
                              style: const TextStyle(
                                fontFamily: 'Bangla',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                canShowCenter
                                    ? 'কেন্দ্র: ${voter.centerName}$boothsStr'
                                    : 'এলাকা: ${voter.area}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Bangla',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                        color: Colors.black,
                        thickness: 1,
                        height: 4,
                      ),

                      // ভোটারের তথ্য সারি
                      _infoRow('ভোটারের নাম:', voter.name, isLarge: true),
                      _infoRow('ভোটার নম্বর:', banglaVoterNo),
                      _infoRow('জন্ম তারিখ:', '$banglaDob  (${voter.gender})'),
                      _infoRow('পিতা/স্বামী:', voter.fatherOrHusband),
                      _infoRow('মাতার নাম:', voter.mother),
                      _infoRow('ঠিকানা:', voter.address),
                      _infoRow('ভোটার এলাকা:', voter.area),
                      _infoRow('ওয়ার্ড নম্বর:', banglaWard),
                      if (voter.publicationDate.isNotEmpty)
                        _infoRow(
                          'তালিকা প্রকাশ:',
                          BanglaHelper.toBanglaDigits(voter.publicationDate),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          // ৩. ফুটার লাইন
          Container(
            width: 492,
            padding: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '❖ নির্বাচনী ভোটার তথ্য স্লিপ ❖',
                  style: TextStyle(
                    fontFamily: 'Bangla',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  effectiveFooter,
                  style: const TextStyle(
                    fontFamily: 'Bangla',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
