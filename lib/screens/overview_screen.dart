import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/candidate.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import 'nid_live_scanner_screen.dart';

class OverviewScreen extends StatefulWidget {
  final Function(int mode, String title) onNavigateSearch;
  const OverviewScreen({super.key, required this.onNavigateSearch});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int _totalVoters = 0;
  int _totalAreas = 0;
  int _totalCenters = 0;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  void _loadOverviewData() async {
    final candidate = await AuthService.getActiveCandidate();

    // 🔴 ওয়েব ভার্সনে রিয়েল ভোটার সংখ্যা ও এরিয়া হিসাব
    if (kIsWeb) {
      if (candidate != null) {
        _totalAreas = candidate.assignedWards.length;
        _totalCenters = candidate.assignedWards
            .map((w) => w.wardNo)
            .toSet()
            .length;
        // সার্ভারের আসল সংখ্যা থাকলে সরাসরি দেখাবে, অন্যথায় ওয়ার্ডগুলোর মোট যোগ করবে
        _totalVoters = candidate.totalVoters > 0
            ? candidate.totalVoters
            : candidate.assignedWards.fold(0, (sum, w) => sum + w.totalVoters);
      }
      if (!mounted) return;
      setState(() {});
      return;
    }

    // মোবাইল ডিভাইসে অফলাইন ডাটাবেজ থেকে লোড
    final areas = await DBService.instance.getDownloadedAreas();
    final count = await DBService.instance.getSearchCount();
    final db = await DBService.instance.database;
    final centerCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT centerName) FROM voters WHERE centerName != ""',
          ),
        ) ??
        0;

    if (!mounted) return;
    setState(() {
      _totalAreas = areas.length;
      _totalVoters = count;
      _totalCenters = centerCount;
    });
  }

  String _getExpiryBadgeText(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diffDays = expiry.difference(today).inDays;

    if (diffDays == 0) {
      return 'আজ শেষ';
    } else if (diffDays < 0) {
      return 'মেয়াদ শেষ';
    } else {
      return 'বাকি: ${BanglaHelper.toBanglaDigits(diffDays.toString())} দিন';
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
    if (kIsWeb || path.startsWith('http')) return NetworkImage(path);
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
        final geo = BanglaHelper.getGeoHierarchyFromStorage(candidate);

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
                                Text(
                                  'দল: ${candidate.partyName} • মার্কা: ${candidate.symbolName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (geo['summary'] != null &&
                                    geo['summary']!.isNotEmpty)
                                  Text(
                                    '${geo['summary']} (${candidate.constituencyOrWard})',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
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
                                    size: 15,
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
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getExpiryBadgeColor(candidate.expiryDate),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getExpiryBadgeText(candidate.expiryDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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

              // ২. ৩টি কার্ড পাশাপাশি (সংরক্ষিত ভোটার, এলাকা ও ভোট কেন্দ্র)
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'সংরক্ষিত এলাকা',
                      '${BanglaHelper.toBanglaDigits(_totalAreas.toString())} টি',
                      Icons.location_city,
                      Colors.teal.shade700,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'ভোট কেন্দ্র',
                      '${BanglaHelper.toBanglaDigits(_totalCenters.toString())} টি',
                      Icons.apartment,
                      Colors.orange.shade800,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text(
                'দ্রুত ভোটার অনুসন্ধান',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // 🔴 ৩০% হাইট কমানো ৬টি সার্চ টাইল
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio:
                    2.9, // 🔴 ৩০% হাইট কমে স্লিম ও দৃষ্টিনন্দন করা হয়েছে
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
                  if (!kIsWeb)
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
              const SizedBox(height: 14),

              // 🔴 "ভোটার ডাটাবেজ ডাউনলোড" বাটনটি এখান থেকে সম্পূর্ণ মুছে ফেলা হয়েছে

              // প্রার্থীর নির্বাচনী ব্যানার
              if (candidate != null &&
                  candidate.bannerImage != null &&
                  candidate.bannerImage!.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (kIsWeb || candidate.bannerImage!.startsWith('http'))
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
                const SizedBox(height: 15),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
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
