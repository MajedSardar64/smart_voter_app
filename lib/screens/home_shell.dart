import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../services/theme_service.dart';
import 'overview_screen.dart';
import 'search_view.dart';
import 'nid_live_scanner_screen.dart';
import 'dashboard_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _activeMenuIndex = 0;
  String _pageTitle = 'ওভারভিউ';
  late Widget _currentBody;

  @override
  void initState() {
    super.initState();
    _currentBody = OverviewScreen(onNavigateSearch: _switchSearchMode);
  }

  void _switchSearchMode(int mode, String title) {
    int menuIdx = 1;
    if (mode == 0) menuIdx = 2; // নাম
    if (mode == 1) menuIdx = 1; // জন্ম তারিখ
    if (mode == 2) menuIdx = 4; // হোল্ডিং
    if (mode == 3) menuIdx = 3; // সিরিয়াল
    if (mode == 4) menuIdx = 5; // ভোটার নং

    setState(() {
      _activeMenuIndex = menuIdx;
      _pageTitle = title;
      _currentBody = SearchView(searchMode: mode);
    });
  }

  Widget _buildDrawerHeaderImage(String? path) {
    if (path != null && path.trim().isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget mainContent = Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      drawer: Drawer(
        child: Container(
          color: isDark ? const Color(0xFF152232) : const Color(0xFF004D40),
          child: SafeArea(
            child: ValueListenableBuilder<Candidate?>(
              valueListenable: AuthService.activeCandidateNotifier,
              builder: (context, candidate, _) {
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // 🔴 প্রার্থীর ৩০% অপাসিটি ব্যানার সহ প্রিমিয়াম ড্রয়ার হেডার
                    Container(
                      height: 165,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF00382E),
                      ),
                      child: Stack(
                        children: [
                          // ৩০% অপাসিটি ব্যাকগ্রাউন্ড ব্যানার
                          if (candidate?.bannerImage != null &&
                              candidate!.bannerImage!.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.30, // ৩০% অপাসিটি
                                child: _buildDrawerHeaderImage(
                                  candidate.bannerImage,
                                ),
                              ),
                            ),

                          // সফট গ্রেডিয়েন্ট ওভারলে
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    (isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF00382E))
                                        .withOpacity(0.85),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ),

                          // প্রার্থীর তথ্য
                          Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white,
                                      backgroundImage:
                                          (candidate?.candidateImage != null &&
                                              candidate!
                                                  .candidateImage!
                                                  .isNotEmpty)
                                          ? (candidate.candidateImage!
                                                    .startsWith('http')
                                                ? NetworkImage(
                                                    candidate.candidateImage!,
                                                  )
                                                : FileImage(
                                                    File(
                                                      candidate.candidateImage!,
                                                    ),
                                                  ) as ImageProvider)
                                          : null,
                                      child:
                                          candidate?.candidateImage == null ||
                                              candidate!.candidateImage!.isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              size: 28,
                                              color: Color(0xFF004D40),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate?.name ?? 'মেনু',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            candidate?.postTitle ?? 'স্মার্ট ভোটার অনুসন্ধান সিস্টেম',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.amberAccent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'স্মার্ট ভোটার অনুসন্ধান সিস্টেম',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ড্রয়ার মেনু আইটেমসমূহ
                    _menuItem(0, Icons.dashboard_outlined, 'ওভারভিউ', () {
                      Navigator.pop(context);
                      setState(() {
                        _activeMenuIndex = 0;
                        _pageTitle = 'ওভারভিউ';
                        _currentBody = OverviewScreen(
                          onNavigateSearch: _switchSearchMode,
                        );
                      });
                    }),
                    _menuItem(
                      1,
                      Icons.calendar_month,
                      'জন্ম তারিখ দিয়ে অনুসন্ধান',
                      () {
                        Navigator.pop(context);
                        _switchSearchMode(1, 'জন্ম তারিখ দিয়ে অনুসন্ধান');
                      },
                    ),
                    _menuItem(
                      2,
                      Icons.people_outline,
                      'নাম দিয়ে অনুসন্ধান',
                      () {
                        Navigator.pop(context);
                        _switchSearchMode(0, 'ভোটার নাম দিয়ে অনুসন্ধান');
                      },
                    ),
                    _menuItem(
                      3,
                      Icons.format_list_numbered,
                      'সিরিয়াল নাম্বার দিয়ে অনুসন্ধান',
                      () {
                        Navigator.pop(context);
                        _switchSearchMode(3, 'ভোটার সিরিয়াল দিয়ে অনুসন্ধান');
                      },
                    ),
                    _menuItem(
                      4,
                      Icons.home_work_outlined,
                      'হোল্ডিং নং দিয়ে অনুসন্ধান',
                      () {
                        Navigator.pop(context);
                        _switchSearchMode(2, 'হোল্ডিং দিয়ে অনুসন্ধান');
                      },
                    ),
                    _menuItem(
                      5,
                      Icons.badge_outlined,
                      'ভোটার নাম্বার দিয়ে অনুসন্ধান',
                      () {
                        Navigator.pop(context);
                        _switchSearchMode(4, 'ভোটার নাম্বার দিয়ে অনুসন্ধান');
                      },
                    ),
                    if (!kIsWeb)
                      _menuItem(
                        6,
                        Icons.camera_alt_outlined,
                        'এন.আই.ডি কার্ড দিয়ে অনুসন্ধান',
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NidLiveScannerScreen(),
                            ),
                          );
                        },
                      ),
                    _menuItem(7, Icons.analytics_outlined, 'ড্যাশবোর্ড', () {
                      Navigator.pop(context);
                      setState(() {
                        _activeMenuIndex = 7;
                        _pageTitle = 'ড্যাশবোর্ড';
                        _currentBody = const DashboardScreen();
                      });
                    }),
                    _menuItem(8, Icons.info_outline, 'আমাদের সম্পর্কে', () {
                      Navigator.pop(context);
                      setState(() {
                        _activeMenuIndex = 8;
                        _pageTitle = 'আমাদের সম্পর্কে';
                        _currentBody = const AboutScreen();
                      });
                    }),
                    _menuItem(9, Icons.settings_outlined, 'সেটিংস', () {
                      Navigator.pop(context);
                      setState(() {
                        _activeMenuIndex = 9;
                        _pageTitle = 'সেটিংস';
                        _currentBody = const SettingsScreen();
                      });
                    }),
                    const Divider(color: Colors.white24, height: 16),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: Colors.amber,
                        size: 20,
                      ),
                      title: Text(
                        isDark ? 'ডার্ক মোড সক্রিয়' : 'লাইট মোড সক্রিয়',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                        ),
                      ),
                      trailing: Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: isDark,
                          activeColor: Colors.amber,
                          onChanged: (val) {
                            ThemeService.setTheme(
                              val ? ThemeMode.dark : ThemeMode.light,
                            );
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      title: const Text(
                        'প্রস্থান',
                        style: TextStyle(color: Colors.white, fontSize: 13.5),
                      ),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: _currentBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeMenuIndex == 2
            ? 0
            : (_activeMenuIndex == 1 ? 1 : (_activeMenuIndex == 4 ? 2 : 0)),
        selectedItemColor: const Color(0xFF00695C),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) _switchSearchMode(0, 'ভোটার নাম দিয়ে অনুসন্ধান');
          if (index == 1) _switchSearchMode(1, 'জন্ম তারিখ দিয়ে অনুসন্ধান');
          if (index == 2) _switchSearchMode(2, 'হোল্ডিং দিয়ে অনুসন্ধান');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search),
            label: 'নাম অনুসন্ধান',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'জন্ম তারিখ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'হোল্ডিং নং',
          ),
        ],
      ),
    );

    if (kIsWeb) {
      return Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: mainContent,
          ),
        ),
      );
    }

    return mainContent;
  }

  Widget _menuItem(int index, IconData icon, String title, VoidCallback onTap) {
    final bool isActive = _activeMenuIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE11D48) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
