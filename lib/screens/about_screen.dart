import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/bangla_helper.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF004D40),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.how_to_vote,
              size: 50,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'স্মার্ট ভোটার ইনফো',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          // ডায়নামিক ভার্সন
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                  : '১.০.০+১';
              return Text(
                'ভার্সন: ${BanglaHelper.toBanglaDigits(version)} (প্রো এডিশন)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              );
            },
          ),
          const SizedBox(height: 20),

          // উদ্দেশ্য বিবরণী কার্ড
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🎯 অ্যাপের মূল উদ্দেশ্য:',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'জাতীয় সংসদ নির্বাচন থেকে শুরু করে উপজেলা, পৌরসভা, সিটি কর্পোরেশন ও ইউনিয়ন পরিষদ নির্বাচনে প্রতিদ্বন্দ্বিতাকারী প্রার্থী ও তাদের মাঠ পর্যায়ের কর্মীদের ভোটার তথ্য অনুসন্ধান এবং তাৎক্ষণিক ভোটার স্লিপ প্রদানের জন্য এই অ্যাপটি তৈরি করা হয়েছে। সম্পূর্ণ অফলাইনে দ্রুততম সময়ে ভোটার সেবা নিশ্চিত করাই এই সিস্টেমের মূল লক্ষ্য।',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🔴 কোম্পানি ও ডেভেলপার পরিচিতি কার্ড (সরদার আইটি আপডেট)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏢 কোম্পানি ও ডেভেলপার পরিচিতি:',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                  ),
                ),
                const Divider(height: 18),
                _infoRow(
                  Icons.business,
                  'কোম্পানির নাম:',
                  'সরদার আইটি (Sardar IT)',
                ),
                _infoRow(Icons.location_on, 'ঠিকানা:', 'ঢাকা, বাংলাদেশ'),
                _infoRow(
                  Icons.phone,
                  'মোবাইল / হেল্পলাইন:',
                  '০১৬১৯০৯৭৫৭১',
                  isAction: true,
                  onTap: () => _makePhoneCall('01619097571'),
                ),
                _infoRow(Icons.language, 'ওয়েবসাইট:', 'আপাতত নেই'),
                _infoRow(Icons.code, 'ডেভেলপার:', 'মাজেদ (Majed)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 🔴 স্বত্ব ও কপিরাইট
          const Text(
            'স্বত্ব © ২০২৪-২০২৮ সরদার আইটি। সর্বস্বত্ব সংরক্ষিত।',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isAction = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF00695C)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
                  color: isAction ? Colors.blue.shade700 : null,
                  decoration: isAction ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
