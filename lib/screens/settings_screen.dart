import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../services/theme_service.dart';
import 'ward_download_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRefreshing = false;

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'থিম নির্বাচন করুন',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode, color: Colors.amber),
              title: const Text('লাইট মোড (Light Mode)'),
              onTap: () {
                ThemeService.setTheme(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.dark_mode,
                color: Colors.deepPurpleAccent,
              ),
              title: const Text('ডার্ক মোড (Dark Mode)'),
              onTap: () {
                ThemeService.setTheme(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.teal),
              title: const Text('ডিভাইস মোড (System Default)'),
              subtitle: const Text(
                'ফোনের সিস্টেম অনুযায়ী পরিবর্তন হবে',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                ThemeService.setTheme(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refreshCandidateData() async {
    setState(() => _isRefreshing = true);
    bool ok = await AuthService.refreshCandidateOnline();
    setState(() => _isRefreshing = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'প্রার্থীর নতুন ছবি, প্রতীক ও ব্যানার সফলভাবে অফলাইনে আপডেট হয়েছে!',
          ),
          backgroundColor: Color(0xFF00695C),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সার্ভারে কানেক্ট করা যায়নি! ইন্টারনেট চেক করুন।'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 1,
            child: ListTile(
              leading: const Icon(
                Icons.palette_outlined,
                color: Color(0xFF004D40),
              ),
              title: const Text(
                'অ্যাপ থিম (লাইট / ডার্ক / ডিভাইস)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('আপনার পছন্দমতো থিম পরিবর্তন করুন'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showThemeDialog(context),
            ),
          ),
          const SizedBox(height: 15),

          _buildButton(
            'পুনরায় ডেটা সিঙ্ক ও ওয়ার্ড পরিবর্তন',
            const Color(0xFFE53935),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const WardDownloadScreen(isFromSettings: true),
                ),
              );
            },
          ),
          const SizedBox(height: 15),

          // প্রার্থীর ছবি, ব্যানার ও প্রতীক রিফ্রেশ বাটন
          _buildButton(
            _isRefreshing
                ? 'সার্ভার থেকে সিঙ্ক হচ্ছে...'
                : 'প্রার্থীর ছবি ও মার্কা রিফ্রেশ',
            const Color(0xFF004D40),
            _isRefreshing ? () {} : _refreshCandidateData,
          ),
          const SizedBox(height: 15),

          _buildButton('ইনস্টল প্রিন্টার', Colors.grey.shade800, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('প্রিন্টার স্ক্যান করা হচ্ছে...')),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
