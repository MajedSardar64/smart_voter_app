import 'package:flutter/services.dart';

class BengaliOcrService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.smart_voter_app/bengali_ocr',
  );

  // অ্যান্ড্রয়েড নেটিভ থেকে অফলাইন বাংলা ও ইংরেজি লেখা এক্সট্রাক্ট করা
  static Future<Map<String, String>> scanAndParseNid(String imagePath) async {
    try {
      final String rawText = await _channel.invokeMethod('extractBanglaText', {
        'imagePath': imagePath,
      });

      print("================= BENGALI OCR RAW TEXT =================");
      print(rawText);
      print("=========================================================");

      return _parseNidDetails(rawText);
    } catch (e) {
      print("Native Bengali OCR Error: $e");
      return {
        'nid': '',
        'name': '',
        'banglaName': '',
        'englishName': '',
        'dob': '',
        'father': '',
        'mother': '',
      };
    }
  }

  // বাংলা ও ইংরেজি হরফ থেকে নিখুঁত তথ্য ফিল্টারিং
  static Map<String, String> _parseNidDetails(String rawText) {
    String extractedNid = '';
    String extractedBanglaName = '';
    String extractedEnglishName = '';
    String extractedFather = '';
    String extractedMother = '';
    String extractedDob = '';

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // ১. বাংলা নাম (নাম: কাওছার আহমেদ / নাম: মোছাঃ আলতাফন খাতুন)
      if (line.contains('নাম:') || line.startsWith('নাম')) {
        extractedBanglaName = line.replaceAll(RegExp(r'নাম[:\s]*'), '').trim();
      }

      // ২. ইংরেজি নাম (Name: KAWSAR AHMED / Mst. Altafan Khatun)
      if (line.startsWith('Name') || line.contains('Name:')) {
        extractedEnglishName = line
            .replaceAll(RegExp(r'Name[:\s]*', caseSensitive: false), '')
            .trim();
        if (i > 0 &&
            extractedBanglaName.isEmpty &&
            !lines[i - 1].contains('গণপ্রজাতন্ত্রী') &&
            !lines[i - 1].contains('National')) {
          extractedBanglaName = lines[i - 1]
              .replaceAll(RegExp(r'নাম[:\s]*'), '')
              .trim();
        }
      }

      // ৩. পিতার নাম (পিতা: মোঃ সায়বালী / পিতা: মোঃ আবু বাক্কার)
      if (line.contains('পিতা:') ||
          line.contains('পিতা') ||
          line.contains('Father')) {
        extractedFather = line
            .replaceAll(
              RegExp(r'(পিতা|Father)[:\s]*', caseSensitive: false),
              '',
            )
            .trim();
        if (extractedFather.isEmpty && i + 1 < lines.length) {
          extractedFather = lines[i + 1].trim();
        }
      }

      // ৪. মাতার নাম (মাতা: মোছাঃ তারা বানু / মাতা: মোছাঃ লিরমন)
      if (line.contains('মাতা:') ||
          line.contains('মাতা') ||
          line.contains('Mother')) {
        extractedMother = line
            .replaceAll(
              RegExp(r'(মাতা|Mother)[:\s]*', caseSensitive: false),
              '',
            )
            .trim();
        if (extractedMother.isEmpty && i + 1 < lines.length) {
          extractedMother = lines[i + 1].trim();
        }
      }

      // ৫. জন্ম তারিখ (17 Mar 1990 / 15 Apr 1962 / ১৫/০৮/১৯৯৫)
      if (line.toLowerCase().contains('birth') ||
          line.contains('Date') ||
          line.contains('জন্ম')) {
        final dobMatch = RegExp(
          r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})|(\d{1,2}[/-]\d{1,2}[/-]\d{4})',
        ).firstMatch(line);
        if (dobMatch != null) {
          extractedDob = dobMatch.group(0)!;
        } else if (i + 1 < lines.length) {
          final nextMatch = RegExp(
            r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})|(\d{1,2}[/-]\d{1,2}[/-]\d{4})',
          ).firstMatch(lines[i + 1]);
          if (nextMatch != null) extractedDob = nextMatch.group(0)!;
        }
      }

      // ৬. NID / ID NO (283 446 5128 / 4171684709)
      if (RegExp(
        r'(NID|ID|NO|No|Card|নং)',
        caseSensitive: false,
      ).hasMatch(line)) {
        final digits = line.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.length >= 10 && digits.length <= 17) {
          extractedNid = digits;
        }
      }
    }

    if (extractedNid.isEmpty) {
      final match = RegExp(r'\b\d{10}\b|\b\d{13}\b|\b\d{17}\b')
          .firstMatch(rawText.replaceAll(' ', ''));
      if (match != null) extractedNid = match.group(0)!;
    }

    return {
      'nid': extractedNid,
      'name': extractedBanglaName.isNotEmpty
          ? extractedBanglaName
          : extractedEnglishName,
      'banglaName': extractedBanglaName,
      'englishName': extractedEnglishName,
      'dob': extractedDob,
      'father': extractedFather,
      'mother': extractedMother,
    };
  }
}
