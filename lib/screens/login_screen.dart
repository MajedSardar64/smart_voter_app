import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/candidate.dart';
import 'ward_download_screen.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // টেস্টিংয়ের সুবিধার জন্য ডিফল্ট ক্রেডেনশিয়াল রাখা হয়েছে
  final _userController = TextEditingController(text: 'saidulvai');
  final _passController = TextEditingController(text: '123');
  bool _isLoading = false;
  Candidate? _savedCandidate; // লোকাল স্টোরেজে সংরক্ষিত প্রার্থীর তথ্য

  @override
  void initState() {
    super.initState();
    _loadSavedCredentialsAndCandidate();
  }

  // 🔴 পূর্বে সফলভাবে লগইন করা ক্রেডেনশিয়াল ও প্রার্থীর তথ্য অফলাইন স্টোরেজ থেকে লোড করা
  void _loadSavedCredentialsAndCandidate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_login_user');
    final savedPass = prefs.getString('saved_login_pass');
    final cand = await AuthService.getActiveCandidate();

    if (!mounted) return;
    setState(() {
      if (cand != null) {
        _savedCandidate = cand;
      }
      if (savedUser != null && savedUser.trim().isNotEmpty) {
        _userController.text = savedUser;
      }
      if (savedPass != null && savedPass.trim().isNotEmpty) {
        _passController.text = savedPass;
      }
    });
  }

  void _handleLogin() async {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      _showAlertDialog('অনুগ্রহ করে ইউজার আইডি এবং পাসওয়ার্ড লিখুন!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.processLogin(user, pass);

      // 🔴 শুধুমাত্র লগইন ১০০% সফল হলেই ইউজার আইডি ও পাসওয়ার্ড সেভ হবে
      if (result['success'] == true) {
        Candidate candidate = result['candidate'];
        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('saved_login_user', user);
        await prefs.setString('saved_login_pass', pass);

        bool hasDownloaded = prefs.getBool('hasDownloadedData') ?? false;

        if (!mounted) return;

        // 🔴 ওয়েব ভার্সন হলে সরাসরি HomeShell-এ প্রবেশ করবে (অপ্রয়োজনীয় ডাউনলোড পেজ বাদ)
        if (kIsWeb || hasDownloaded) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeShell()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WardDownloadScreen(candidate: candidate),
            ),
          );
        }
      } else {
        if (!mounted) return;
        _showAlertDialog(result['message'] ?? 'Login failed.');
      }
    } catch (e) {
      if (!mounted) return;
      _showAlertDialog('সার্ভার এরর: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text(
              'বিজ্ঞপ্তি',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
            ),
            child: const Text('ঠিক আছে', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // প্রার্থীর ছবি লোডার (ওয়েব ও মোবাইল উভয় ডিভাইসেই নিরাপদ)
  Widget _buildCandidateImage(String? path, {double size = 72}) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person, size: size * 0.6, color: Colors.white),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person, size: size * 0.6, color: Colors.white),
        );
      }
    }
    return Icon(Icons.person, size: size * 0.6, color: Colors.white);
  }

  // প্রার্থীর মার্কার লোডার (ওয়েব ও মোবাইল উভয় ডিভাইসেই নিরাপদ)
  Widget _buildSymbolImage(String? path, {double size = 48}) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.how_to_vote, size: size * 0.6, color: Colors.black87),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.how_to_vote, size: size * 0.6, color: Colors.black87),
        );
      }
    }
    return Icon(Icons.how_to_vote, size: size * 0.6, color: Colors.black87);
  }

  // 🔴 প্রার্থীর সংরক্ষিত তথ্য দিয়ে স্বয়ংক্রিয়ভাবে তৈরি কাস্টম নির্বাচনী ব্যানার
  Widget _buildCustomCandidateBanner(Candidate cand, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF005646), const Color(0xFF002E26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amberAccent.withOpacity(0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (cand.electionTitle.isNotEmpty || cand.electionDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${cand.electionDate.isNotEmpty ? "${cand.electionDate} • " : ""}${cand.electionTitle}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Row(
            children: [
              SizedBox(
                width: 98,
                height: 78,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amberAccent, width: 2),
                        color: const Color(0xFF004D40),
                      ),
                      child: ClipOval(
                        child: _buildCandidateImage(
                          cand.candidateImage,
                          size: 72,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.black87, width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildSymbolImage(cand.symbolImage, size: 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cand.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Bangla',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cand.symbolName} মার্কায় ভোট দিন',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Bangla',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cand.postTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 3),

                    Text(
                      'দল: ${cand.partyName}${cand.constituencyOrWard.isNotEmpty ? " • ${cand.constituencyOrWard}" : ""}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B131E)
            : const Color(0xFF00382E),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // লোকাল স্টোরেজে ডেটা থাকলে স্বয়ংক্রিয়ভাবে কাস্টম ব্যানারটি দেখাবে
                  if (_savedCandidate != null)
                    _buildCustomCandidateBanner(_savedCandidate!, isDark),

                  // মূল লগইন কার্ড
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF152232)
                          : const Color(0xFF004D40),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.4 : 0.25,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFF00695C),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.how_to_vote,
                            size: 48,
                            color: Colors.amberAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'স্মার্ট ভোটার ইনফো',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'মাঠ পর্যায়ের কর্মী ও ভোটার অনুসন্ধান সিস্টেম',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ইউজার আইডি ফিল্ড
                        TextField(
                          controller: _userController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF00382E),
                            labelText: 'প্রার্থী ইউজার আইডি',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: Colors.white70,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.amberAccent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // পাসওয়ার্ড ফিল্ড
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF00382E),
                            labelText: 'পাসওয়ার্ড',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.white70,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.amberAccent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // লগইন বাটন
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'যাচাই হচ্ছে...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'লগইন করুন',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
