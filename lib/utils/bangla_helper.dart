import 'package:flutter/services.dart';

class BanglaHelper {
  static String toBanglaDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < en.length; i++) {
      input = input.replaceAll(en[i], bn[i]);
    }
    return input;
  }

  static String toEnglishDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < bn.length; i++) {
      input = input.replaceAll(bn[i], en[i]);
    }
    return input;
  }

  static String formatGender(String gender) {
    String g = gender.trim().toLowerCase();
    if (g == 'male' || g == 'm' || g == 'পুরুষ') return 'পুরুষ';
    if (g == 'female' || g == 'f' || g == 'মহিলা') return 'মহিলা';
    if (g == 'hijra' || g == 'other' || g == 'হিজড়া' || g == 'হিজরা') {
      return 'হিজড়া';
    }
    return gender.isEmpty ? 'পুরুষ' : gender;
  }

  static String formatDobToBangla(String dobStr) {
    if (dobStr.trim().isEmpty) return '';
    String enDob = toEnglishDigits(dobStr.trim());
    const monthsEn = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];

    final textMatch = RegExp(r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$')
        .firstMatch(enDob);
    if (textMatch != null) {
      String day = textMatch.group(1)!.padLeft(2, '0');
      String monthStr = textMatch.group(2)!.toLowerCase();
      String year = textMatch.group(3)!;

      for (int i = 0; i < monthsEn.length; i++) {
        if (monthStr.startsWith(monthsEn[i])) {
          String mm = (i + 1).toString().padLeft(2, '0');
          return toBanglaDigits('$day/$mm/$year');
        }
      }
    }

    final isoMatch = RegExp(r'^(\d{4})[\-\/](\d{1,2})[\-\/](\d{1,2})$')
        .firstMatch(enDob);
    if (isoMatch != null) {
      String year = isoMatch.group(1)!;
      String month = isoMatch.group(2)!.padLeft(2, '0');
      String day = isoMatch.group(3)!.padLeft(2, '0');
      return toBanglaDigits('$day/$month/$year');
    }

    final slashMatch = RegExp(r'^(\d{1,2})[\-\/\.](\d{1,2})[\-\/\.](\d{4})$')
        .firstMatch(enDob);
    if (slashMatch != null) {
      String day = slashMatch.group(1)!.padLeft(2, '0');
      String month = slashMatch.group(2)!.padLeft(2, '0');
      String year = slashMatch.group(3)!;
      return toBanglaDigits('$day/$month/$year');
    }

    return toBanglaDigits(dobStr);
  }

  static String formatDobToNumericBangla(String dobStr) =>
      formatDobToBangla(dobStr);

  static List<String> generateAddressVariations(String input) {
    if (input.trim().isEmpty) return [];
    String cleaned = input.trim();
    String bnDigits = toBanglaDigits(cleaned);
    String enDigits = toEnglishDigits(cleaned);

    String converted = bnDigits
        .replaceAll(RegExp(r'A-', caseSensitive: false), 'এ-')
        .replaceAll(RegExp(r'B-', caseSensitive: false), 'বি-')
        .replaceAll(RegExp(r'C-', caseSensitive: false), 'সি-')
        .replaceAll(RegExp(r'D-', caseSensitive: false), 'ডি-')
        .replaceAll(RegExp(r'Holding', caseSensitive: false), 'হোল্ডিং')
        .replaceAll(RegExp(r'Road', caseSensitive: false), 'রোড');

    return {cleaned, bnDigits, enDigits, converted}.toList();
  }

  static List<String> generateDobVariations(String rawInput) {
    if (rawInput.trim().isEmpty) return [];
    String input = toEnglishDigits(rawInput.trim());
    List<String> variations = [
      rawInput.trim(),
      toBanglaDigits(rawInput.trim()),
    ];

    const monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    int? day, month, year;

    final numMatch = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$')
        .firstMatch(input);
    if (numMatch != null) {
      day = int.tryParse(numMatch.group(1)!);
      month = int.tryParse(numMatch.group(2)!);
      year = int.tryParse(numMatch.group(3)!);
    }

    final textMatch = RegExp(
      r'^(\d{1,2})\s+([A-Za-z\u0980-\u09FF]+)\s+(\d{4})$',
    ).firstMatch(input);
    if (textMatch != null) {
      day = int.tryParse(textMatch.group(1)!);
      String mStr = textMatch.group(2)!.toLowerCase();
      year = int.tryParse(textMatch.group(3)!);
      for (int i = 0; i < monthsEn.length; i++) {
        if (monthsEn[i].toLowerCase().startsWith(
          mStr.substring(0, mStr.length >= 3 ? 3 : mStr.length),
        )) {
          month = i + 1;
          break;
        }
      }
    }

    if (day != null &&
        month != null &&
        year != null &&
        month >= 1 &&
        month <= 12) {
      String dd = day.toString().padLeft(2, '0');
      String mm = month.toString().padLeft(2, '0');
      String yyyy = year.toString();
      String mName = monthsEn[month - 1];

      variations.addAll([
        '$dd $mName $yyyy',
        '$dd/$mm/$yyyy',
        '$dd-$mm-$yyyy',
        '$yyyy-$mm-$dd',
        toBanglaDigits('$dd/$mm/$yyyy'),
        toBanglaDigits('$dd-$mm-$yyyy'),
        '$day/$month/$yyyy',
      ]);
    }
    return variations.toSet().toList();
  }
}

// জন্মতারিখ অটো-মাস্ক ফরম্যাটার (২ সংখ্যা পর পর স্ল্যাশ বসাবে ও বাংলায় কনভার্ট করবে)
class DateOfBirthMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // শুধুমাত্র সংখ্যাগুলো ফিল্টার করা
    String rawDigits = BanglaHelper.toBanglaDigits(
      newValue.text.replaceAll(RegExp(r'[^\d০-৯]'), ''),
    );

    // সর্বোচ্চ ৮ ডিজিট (দিন ২ + মাস ২ + বছর ৪)
    if (rawDigits.length > 8) {
      rawDigits = rawDigits.substring(0, 8);
    }

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < rawDigits.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(rawDigits[i]);
    }

    String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// হোল্ডিং ঠিকানার অটো-কনভার্টার
class AutoBanglaTextFormatter extends TextInputFormatter {
  final bool isAddress;
  AutoBanglaTextFormatter({this.isAddress = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    String converted = BanglaHelper.toBanglaDigits(text);

    if (isAddress) {
      converted = converted
          .replaceAll('A-', 'এ-')
          .replaceAll('a-', 'এ-')
          .replaceAll('B-', 'বি-')
          .replaceAll('b-', 'বি-')
          .replaceAll('C-', 'সি-')
          .replaceAll('c-', 'সি-')
          .replaceAll('D-', 'ডি-')
          .replaceAll('d-', 'ডি-');
    }

    return newValue.copyWith(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}
