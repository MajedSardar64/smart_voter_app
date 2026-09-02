import 'dart:io';

import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import 'nid_live_scanner_screen.dart';
import 'ward_download_screen.dart';

class OverviewScreen extends StatefulWidget {
  final Function(int mode, String title) onNavigateSearch;
  const OverviewScreen({super.key, required this.onNavigateSearch});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int _totalVoters = 0;
  int _totalAreas = 0;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  void _loadOverviewData() async {
    await AuthService.getActiveCandidate();
    final areas = await DBService.instance.getDownloadedAreas();
    final count = await DBService.instance.getSearchCount();

    if (!mounted) return;
    setState(() {
      _totalAreas = areas.length;
      _totalVoters = count;
    });
  }

  String _getExpiryBadgeText(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diffDays = expiry.difference(today).inDays;

    if (diffDays == 0) {
      return 'আজই শেষ দিন';
    } else if (diffDays < 0) {
      return 'মেয়াদ শেষ';
    } else {
      return 'মেয়াদ বাকি: ${BanglaHelper.toBanglaDigits(diffDays.toString())} দিন';
    }
  }

  Color _getExpiryBadgeColor(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diffDays = expiry.difference(today).inDays;

    if (diffDays <= 0) return const Color(0xFFDC2626);
    if (diffDays <= 10) return const Color(0xFFDC2626);
    if (diffDays <= 30) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  ImageProvider? _getImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return NetworkImage(path);
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<Candidate?>(
      valueListenable: AuthService.activeCandidateNotifier,
      builder: (context, candidate, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ১. প্রার্থীর সম্পূর্ণ পরিচিতি কার্ড
              if (candidate != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF004D40),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white,
                            backgroundImage: _getImageProvider(
                              candidate.candidateImage,
                            ),
                            child:
                                candidate.candidateImage == null ||
                                    candidate.candidateImage!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Color(0xFF004D40),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  candidate.postTitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // দল ও প্রতীক
                                Text(
                                  'দল: ${candidate.partyName} • মার্কা: ${candidate.symbolName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // নির্বাচন স্তর ও আসন/ওয়ার্ড
                                Text(
                                  '${candidate.electionType}${candidate.constituencyOrWard.isNotEmpty ? " (${candidate.constituencyOrWard})" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // নির্বাচন তারিখ ও "আজই শেষ দিন" এক্সপায়রি ব্যাজ
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_available,
                                    color: Colors.amberAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      candidate.electionDate.isNotEmpty
                                          ? candidate.electionDate
                                          : 'নির্বাচন শীঘ্রই',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getExpiryBadgeColor(candidate.expiryDate),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _getExpiryBadgeText(candidate.expiryDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // ২. সংরক্ষিত ডাটাবেজ সামারি কার্ড
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'সংরক্ষিত ভোটার',
                      BanglaHelper.toBanglaDigits(_totalVoters.toString()),
                      Icons.people_alt,
                      Colors.blue.shade700,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'সংরক্ষিত এলাকা',
                      '${BanglaHelper.toBanglaDigits(_totalAreas.toString())} টি',
                      Icons.location_city,
                      Colors.teal.shade700,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ৩. দ্রুত ভোটার অনুসন্ধান (৬টি অপশন)
              const Text(
                'দ্রুত ভোটার অনুসন্ধান',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.1,
                children: [
                  _actionTile(
                    'নাম দিয়ে অনুসন্ধান',
                    Icons.person_search,
                    Colors.indigo,
                    () =>
                        widget.onNavigateSearch(0, 'ভোটার নাম দিয়ে অনুসন্ধান'),
                    isDark,
                  ),
                  _actionTile(
                    'ভোটার নাম্বার দিয়ে',
                    Icons.badge_outlined,
                    Colors.blue.shade700,
                    () => widget.onNavigateSearch(
                      4,
                      'ভোটার নাম্বার দিয়ে অনুসন্ধান',
                    ),
                    isDark,
                  ),
                  _actionTile(
                    'জন্ম তারিখ দিয়ে',
                    Icons.calendar_month,
                    Colors.deepOrange,
                    () =>
                        widget.onNavigateSearch(1, 'জন্ম তারিখ দিয়ে অনুসন্ধান'),
                    isDark,
                  ),
                  _actionTile(
                    'সিরিয়াল নাম্বার',
                    Icons.format_list_numbered,
                    Colors.purple,
                    () => widget.onNavigateSearch(
                      3,
                      'ভোটার সিরিয়াল দিয়ে অনুসন্ধান',
                    ),
                    isDark,
                  ),
                  _actionTile(
                    'হোল্ডিং নং দিয়ে',
                    Icons.home_work_outlined,
                    Colors.teal,
                    () => widget.onNavigateSearch(2, 'হোল্ডিং দিয়ে অনুসন্ধান'),
                    isDark,
                  ),
                  _actionTile(
                    'এন.আই.ডি ক্যামেরা',
                    Icons.camera_alt_outlined,
                    Colors.green.shade700,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NidLiveScannerScreen(),
                        ),
                      );
                    },
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ৪. ডাটাবেজ ডাউনলোড শর্টকাট
              Card(
                elevation: 0.5,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.cloud_download,
                    color: Color(0xFFE11D48),
                    size: 24,
                  ),
                  title: const Text(
                    'ভোটার ডাটাবেজ ডাউনলোড ও সিঙ্ক',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'ইউনিয়ন ও ওয়ার্ড অফলাইনে সেভ করুন',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const WardDownloadScreen(isFromSettings: true),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ৫. প্রার্থীর নির্বাচনী ব্যানার
              if (candidate?.bannerImage != null &&
                  candidate!.bannerImage!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: candidate.bannerImage!.startsWith('http')
                      ? Image.network(
                          candidate.bannerImage!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : Image.file(
                          File(candidate.bannerImage!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
