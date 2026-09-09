import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/candidate.dart';
import '../services/db_service.dart';
import '../services/theme_service.dart';
import '../widgets/slips/slip_template.dart';
import 'login_screen.dart';
import 'ward_download_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRefreshing = false;
  bool _isThermalEnabled = true;
  String _selectedSlipFormat = 'format_1';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isThermalEnabled = prefs.getBool('is_thermal_printer_enabled') ?? true;
      _selectedSlipFormat = prefs.getString('voter_slip_format') ?? 'format_1';
    });
  }

  void _togglePrinterSwitch(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_thermal_printer_enabled', val);
    setState(() => _isThermalEnabled = val);
  }

  // 🔴 ডায়নামিক ফরম্যাট চয়েস ডায়ালগ
  void _showSlipFormatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.style, color: Color(0xFF004D40)),
            SizedBox(width: 8),
            Text(
              'ভোটার স্লিপ ফরম্যাট নির্বাচন',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SlipRegistry.templates.map((template) {
              return Column(
                children: [
                  RadioListTile<String>(
                    value: template.id,
                    groupValue: _selectedSlipFormat,
                    title: Text(
                      template.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      template.description,
                      style: const TextStyle(fontSize: 11),
                    ),
                    activeColor: const Color(0xFF004D40),
                    onChanged: (val) async {
                      if (val == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('voter_slip_format', val);
                      setState(() => _selectedSlipFormat = val);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _clearAllAppCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'ক্যাশ ও ডেটা ক্লিয়ার করবেন?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'এটি আপনার অ্যাপের সমস্ত সেভ করা ক্যাশ, পুরোনো ভোটার তালিকা এবং প্রিফারেন্স সম্পূর্ণ মুছে ফ্রেশ করে দেবে। এরপর আপনাকে পুনরায় লগইন করতে হবে।',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না, বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'হ্যাঁ, ক্লিয়ার করুন',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!kIsWeb) {
      await DBService.instance.clearAllVoters();
    }

    AuthService.activeCandidateNotifier.value = null;

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showPrinterHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.print, color: Color(0xFF004D40)),
            SizedBox(width: 8),
            Text(
              'প্রিন্টার কানেকশন নিয়ম',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          '১. পোর্টেবল ব্লুটুথ থার্মাল প্রিন্টার ব্যবহার করতে ফোনের Settings > Bluetooth এ গিয়ে প্রিন্টারটি আগে "Pair" করে নিন।\n\n'
          '২. অথবা সরাসরি প্লে-স্টোরের "RawBT" অ্যাপ ওপেন করে প্রিন্টার সিলেক্ট করুন (এটি সবচেয়ে দ্রুত কাজ করে)।\n\n'
          '৩. ওয়েব ভার্সনে যেকোনো ক্যাবল প্রিন্টার দিয়ে ব্রাউজারের স্বাভাবিক প্রিন্ট ডায়ালগ দিয়ে প্রিন্ট করা যাবে।',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
            ),
            child: const Text('বুঝেছি', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    // ডায়নামিকভাবে বর্তমান নির্বাচিত ফরম্যাটের নাম পড়া
    final currentTemplate = SlipRegistry.getTemplate(_selectedSlipFormat);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'আপনার পছন্দমতো থিম পরিবর্তন করুন',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: () => _showThemeDialog(context),
            ),
          ),
          const SizedBox(height: 10),

          // ডায়নামিক ভোটার স্লিপ ফরম্যাট সিলেক্টর কার্ড
          Card(
            elevation: 1,
            child: ListTile(
              leading: const Icon(
                Icons.style_outlined,
                color: Color(0xFF004D40),
              ),
              title: const Text(
                'ভোটার স্লিপ ফরম্যাট নির্বাচন',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'বর্তমান ফরম্যাট: ${currentTemplate.name}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: _showSlipFormatDialog,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'প্রিন্টার কন্ট্রোল',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF004D40),
                    ),
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'স্মার্ট থার্মাল প্রিন্টার মোড',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      _isThermalEnabled
                          ? 'সক্রিয় (সরাসরি থার্মাল প্রিন্টারে যাবে)'
                          : 'বন্ধ (সাধারণ PDF প্রিভিউ ওপেন হবে)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: _isThermalEnabled,
                    activeColor: const Color(0xFF004D40),
                    onChanged: _togglePrinterSwitch,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _showPrinterHelp,
                    icon: const Icon(
                      Icons.help_outline,
                      size: 16,
                      color: Color(0xFF004D40),
                    ),
                    label: const Text(
                      'প্রিন্টার কানেক্ট করার নিয়ম দেখুন',
                      style: TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (!kIsWeb) ...[
            _buildButton(
              'ভোটার ডেটাবেজ ও কেন্দ্র অফলাইন সিঙ্ক (Sync Wards)',
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
            const SizedBox(height: 10),
          ],

          _buildButton(
            _isRefreshing
                ? 'সার্ভার থেকে সিঙ্ক হচ্ছে...'
                : 'প্রার্থীর নতুন এলাকা ও প্রোফাইল রিফ্রেশ',
            const Color(0xFF004D40),
            _isRefreshing
                ? () {}
                : () async {
                    setState(() => _isRefreshing = true);
                    bool ok = await AuthService.refreshCandidateOnline();
                    setState(() => _isRefreshing = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'প্রার্থীর তথ্য সফলভাবে আপডেট হয়েছে!'
                              : 'সার্ভারে কানেক্ট করা যায়নি!',
                        ),
                        backgroundColor: ok
                            ? const Color(0xFF004D40)
                            : Colors.red,
                      ),
                    );
                  },
          ),
          const SizedBox(height: 12),

          _buildButton(
            'ক্যাশ ও ডেটা ক্লিয়ার করুন (Clear Cache & Reset)',
            Colors.red.shade700,
            _clearAllAppCache,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
