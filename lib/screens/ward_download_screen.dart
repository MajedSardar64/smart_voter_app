import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../services/db_service.dart';
import '../services/voter_download_manager.dart';
import '../utils/bangla_helper.dart';
import 'home_shell.dart';

class WardDownloadScreen extends StatefulWidget {
  final Candidate? candidate;
  final bool isFromSettings;

  const WardDownloadScreen({
    super.key,
    this.candidate,
    this.isFromSettings = false,
  });

  @override
  State<WardDownloadScreen> createState() => _WardDownloadScreenState();
}

class _WardDownloadScreenState extends State<WardDownloadScreen> {
  Candidate? _candidate;

  // 🔴 সম্পূর্ণ ইউনিক কি দিয়ে সিলেকশন ট্র্যাকিং (ইউনিয়ন + এরিয়া নাম)
  final Set<String> _selectedAreaKeys = {};
  List<String> _alreadyDownloadedAreas = [];
  bool _isRefreshingAreas = false;
  String? _updatingAreaName;

  String _getUniqueKey(WardAllocation w) => '${w.unionOrPouro}__${w.areaName}';

  @override
  void initState() {
    super.initState();
    _candidate = widget.candidate;
    _initDataAndSyncOnline();
    VoterDownloadManager.instance.progressNotifier.addListener(
      _onDownloadStateChanged,
    );
  }

  @override
  void dispose() {
    VoterDownloadManager.instance.progressNotifier.removeListener(
      _onDownloadStateChanged,
    );
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (!mounted) return;
    final state = VoterDownloadManager.instance.progressNotifier.value;

    if (state.status == DownloadStatus.completed) {
      if (_selectedAreaKeys.isNotEmpty) {
        setState(() {
          _selectedAreaKeys.clear();
        });
      }
      _refreshLocalDownloadedList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সফলভাবে ভোটার ডাটা সংরক্ষণ সম্পন্ন হয়েছে!'),
          backgroundColor: Color(0xFF00695C),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (state.status == DownloadStatus.error &&
        state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _refreshLocalDownloadedList() async {
    final downloaded = await DBService.instance.getDownloadedAreas();
    if (!mounted) return;
    setState(() {
      _alreadyDownloadedAreas = downloaded;
    });
  }

  void _initDataAndSyncOnline() async {
    try {
      _candidate ??= await AuthService.getActiveCandidate();
      await VoterDownloadManager.instance.syncWithDatabase();
      final downloaded = await DBService.instance.getDownloadedAreas();
      if (!mounted) return;
      setState(() {
        _alreadyDownloadedAreas = downloaded;
      });
    } catch (e) {
      print('WardDownloadScreen init error: $e');
    } finally {
      if (mounted && _candidate == null) {
        _candidate = await AuthService.getActiveCandidate();
        setState(() {});
      }
    }
  }

  void _manualRefreshAreas({bool showToast = true}) async {
    setState(() => _isRefreshingAreas = true);
    bool updated = await AuthService.refreshCandidateOnline();
    if (updated) {
      final freshCandidate = await AuthService.getActiveCandidate();
      if (mounted && freshCandidate != null) {
        setState(() {
          _candidate = freshCandidate;
        });
      }
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'সার্ভার থেকে প্রার্থীর এলাকা ও প্রশাসনিক তথ্য আপডেট হয়েছে!',
            ),
            backgroundColor: Color(0xFF00695C),
          ),
        );
      }
    }
    if (mounted) setState(() => _isRefreshingAreas = false);
  }

  void _reSyncSingleAreaAction(WardAllocation areaItem) async {
    setState(() => _updatingAreaName = areaItem.areaName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${areaItem.areaName}" এলাকার ডাটা সার্ভার থেকে আপডেট হচ্ছে...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    bool ok = await VoterDownloadManager.instance.reSyncSingleArea(
      areaItem.areaName,
      areaCode: areaItem.areaCode,
    );
    final downloaded = await DBService.instance.getDownloadedAreas();

    if (!mounted) return;
    setState(() {
      _alreadyDownloadedAreas = downloaded;
      _updatingAreaName = null;
      _selectedAreaKeys.remove(_getUniqueKey(areaItem));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'সফলভাবে "${areaItem.areaName}" এলাকার নতুন তথ্য আপডেট হয়েছে!'
              : 'আপডেট ব্যর্থ হয়েছে! ইন্টারনেট চেক করুন।',
        ),
        backgroundColor: ok ? const Color(0xFF00695C) : Colors.red,
      ),
    );
  }

  void _toggleSelectAll(bool selectAll, List<WardAllocation> allAreas) {
    setState(() {
      if (selectAll) {
        for (var w in allAreas) {
          _selectedAreaKeys.add(_getUniqueKey(w));
        }
      } else {
        _selectedAreaKeys.clear();
      }
    });
  }

  void _toggleUnion(List<WardAllocation> unionWards, bool isSelected) {
    setState(() {
      for (var w in unionWards) {
        final k = _getUniqueKey(w);
        if (isSelected) {
          _selectedAreaKeys.add(k);
        } else {
          _selectedAreaKeys.remove(k);
        }
      }
    });
  }

  // 🔴 শতভাগ নির্ভুল ব্যাচ ডিলিট ইঞ্জিন (সিঙ্গেল ডিলিটের মতো নিশ্চিতভাবে কাজ করবে)
  void _startBatchDelete(
    List<WardAllocation> allAreas,
    Set<String> activeSavedAreas,
  ) async {
    final selectedWards = allAreas
        .where((w) => _selectedAreaKeys.contains(_getUniqueKey(w)))
        .toList();

    // সংরক্ষিত থাকা নির্বাচিত এলাকার নামগুলো সংগ্রহ
    final List<String> areasToDelete = selectedWards
        .where((w) => activeSavedAreas.contains(w.areaName.trim()))
        .map((w) => w.areaName.trim())
        .toSet()
        .toList();

    if (areasToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('নির্বাচিত এলাকাগুলোর কোনোটি এখনো ফোনে সংরক্ষিত নেই!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'একসাথে মুছবেন?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'নির্বাচিত ${BanglaHelper.toBanglaDigits(areasToDelete.length.toString())} টি এলাকার সমস্ত ভোটার তথ্য ফোন থেকে মুছে ফেলতে চান?',
          style: const TextStyle(fontSize: 13.5),
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
              'হ্যাঁ, মুছে ফেলুন',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // লোডিং নির্দেশক
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                '${BanglaHelper.toBanglaDigits(areasToDelete.length.toString())} টি এলাকা মুছে ফেলা হচ্ছে...',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 🔴 এক ট্রানজ্যাকশনে সম্পূর্ণ ডিলিট
    await DBService.instance.deleteMultipleAreas(areasToDelete);
    await VoterDownloadManager.instance.syncWithDatabase();
    final downloaded = await DBService.instance.getDownloadedAreas();

    if (!mounted) return;
    Navigator.pop(context); // ডায়ালগ বন্ধ করা

    setState(() {
      _alreadyDownloadedAreas = downloaded;
      _selectedAreaKeys.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'সফলভাবে ${BanglaHelper.toBanglaDigits(areasToDelete.length.toString())} টি এলাকার তথ্য মুছে ফেলা হয়েছে!',
        ),
        backgroundColor: const Color(0xFF00695C),
      ),
    );
  }

  void _confirmDeleteSingleArea(String areaName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'এলাকা মুছে ফেলবেন?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'আপনি কি "$areaName" এলাকার ভোটার তথ্য মুছে ফেলতে চান?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DBService.instance.deleteAreaVoters(areaName);
              await VoterDownloadManager.instance.syncWithDatabase();
              final downloaded = await DBService.instance.getDownloadedAreas();

              if (!mounted) return;
              setState(() {
                _alreadyDownloadedAreas = downloaded;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('মুছুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startDownloadOrUpdate(
    List<WardAllocation> allAreas, {
    bool isUpdate = false,
  }) async {
    if (_selectedAreaKeys.isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ইন্টারনেট সংযোগ নেই! ইন্টারনেট চালু করে চেষ্টা করুন।'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final targetWards = allAreas
        .where((w) => _selectedAreaKeys.contains(_getUniqueKey(w)))
        .toList();

    // 🔴 বাটনে চাপ দেওয়ার সাথে সাথে স্বয়ংক্রিয়ভাবে টিক চিহ্ন ছেড়ে দেওয়া
    setState(() {
      _selectedAreaKeys.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUpdate
              ? '${BanglaHelper.toBanglaDigits(targetWards.length.toString())} টি এলাকার ডাটা আপডেট শুরু হচ্ছে...'
              : '${BanglaHelper.toBanglaDigits(targetWards.length.toString())} টি এলাকার ডাটা ডাউনলোড শুরু হচ্ছে...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    VoterDownloadManager.instance.startOrganizedBatchDownload(
      targetWards,
      isUpdateMode: isUpdate,
    );
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  Widget _geoBadge(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF004D40).withValues(alpha: 0.25),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontFamily: 'Bangla',
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF004D40),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_candidate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ভোটার এলাকা ও সিঙ্ক')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00695C)),
              const SizedBox(height: 14),
              const Text('প্রার্থীর তথ্য লোড হচ্ছে...'),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final c = await AuthService.getActiveCandidate();
                  if (mounted) setState(() => _candidate = c);
                },
                child: const Text('পুনরায় চেষ্টা করুন'),
              ),
            ],
          ),
        ),
      );
    }

    final Map<String, List<WardAllocation>> unionGroups = {};
    final Set<String> seenAreaKeys = {};
    final List<WardAllocation> allUniqueAreas = [];

    for (var w in _candidate!.assignedWards) {
      String groupKey = w.unionOrPouro.isNotEmpty
          ? w.unionOrPouro
          : 'নির্ধারিত এলাকা';

      String dedupeKey = _getUniqueKey(w);
      if (!seenAreaKeys.contains(dedupeKey)) {
        seenAreaKeys.add(dedupeKey);
        unionGroups.putIfAbsent(groupKey, () => []).add(w);
        allUniqueAreas.add(w);
      }
    }

    final int totalCandidateAreas = allUniqueAreas.length;
    final bool isAllSelected =
        _selectedAreaKeys.length == totalCandidateAreas &&
        totalCandidateAreas > 0;

    final geo = BanglaHelper.getGeoHierarchyFromStorage(_candidate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ভোটার এলাকা ও সিঙ্ক'),
        automaticallyImplyLeading: widget.isFromSettings,
        actions: [
          IconButton(
            icon: _isRefreshingAreas
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00695C),
                    ),
                  )
                : const Icon(Icons.sync, color: Color(0xFF00695C)),
            tooltip: 'সার্ভার থেকে এলাকা রিফ্রেশ',
            onPressed: _isRefreshingAreas
                ? null
                : () => _manualRefreshAreas(showToast: true),
          ),
          TextButton.icon(
            onPressed: _navigateToHome,
            icon: const Icon(Icons.home, color: Color(0xFF00695C)),
            label: const Text(
              'হোমে যান',
              style: TextStyle(
                color: Color(0xFF00695C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔴 মাঠ পর্যায়ের কর্মীদের জন্য সুস্পষ্ট নির্দেশনামূলক ব্যানার
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark
                              ? Colors.amber.shade200
                              : const Color(0xFF78350F),
                          fontFamily: 'Bangla',
                        ),
                        children: const [
                          TextSpan(
                            text: 'মাঠ পর্যায়ের কর্মীদের জন্য নির্দেশনা: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: 'আপনি যে ইউনিয়ন বা ওয়ার্ডে কাজ করছেন, শুধুমাত্র সেই ইউনিয়ন/ওয়ার্ডের পাশে টিক দিয়ে ডাউনলোড করে নিন। পুরো উপজেলার সব এলাকা একসাথে ডাউনলোড না করলে আপনার ফোনের মেমোরি ফাঁকা থাকবে এবং চোখের পলকে দ্রুততম সময়ে নির্ভুল ভোটার রেজাল্ট পাবেন।',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // প্রশাসনিক অঞ্চল কার্ড
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF004D40), width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF004D40),
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'প্রশাসনিক অঞ্চল:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF004D40),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _candidate!.constituencyOrWard,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (geo['division']!.isNotEmpty)
                        _geoBadge('বিভাগ:', geo['division']!),
                      if (geo['district']!.isNotEmpty)
                        _geoBadge('জেলা:', geo['district']!),
                      if (geo['upazila']!.isNotEmpty)
                        _geoBadge('উপজেলা:', geo['upazila']!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 🔴 প্রগ্রেস কার্ড (শুধুমাত্র এই ক্ষুদ্র অংশটুকু ValueListenableBuilder দিয়ে রি-বিল্ড হবে, পুরো স্ক্রিন নয়!)
            ValueListenableBuilder<DownloadProgressState>(
              valueListenable: VoterDownloadManager.instance.progressNotifier,
              builder: (context, downloadState, _) {
                final bool isDownloading =
                    downloadState.status == DownloadStatus.running;

                final Set<String> savedAreas = {
                  ..._alreadyDownloadedAreas,
                  ...downloadState.savedAreaNames,
                };

                int realSavedCount = allUniqueAreas
                    .where((w) => savedAreas.contains(w.areaName))
                    .length;
                int realPendingCount = totalCandidateAreas - realSavedCount;
                if (realPendingCount < 0) realPendingCount = 0;

                final int totalDownloading = downloadState.totalAreasCount;
                final int completedDownloading =
                    downloadState.completedAreasCount;
                final int remainingDownloading =
                    (totalDownloading - completedDownloading).clamp(
                      0,
                      totalDownloading,
                    );

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _counterBadge(
                            'সংরক্ষিত এলাকা',
                            '${BanglaHelper.toBanglaDigits(realSavedCount.toString())} টি',
                            Colors.green.shade700,
                          ),
                          _counterBadge(
                            'বাকি এলাকা',
                            '${BanglaHelper.toBanglaDigits(realPendingCount.toString())} টি',
                            Colors.orange.shade800,
                          ),
                          _counterBadge(
                            'মোট ভোটার',
                            BanglaHelper.toBanglaDigits(
                              downloadState.totalVotersSaved.toString(),
                            ),
                            Colors.blue.shade700,
                          ),
                        ],
                      ),

                      // প্রগ্রেস ইন্ডিকেটর
                      if (isDownloading) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:
                                (completedDownloading > 0 &&
                                    totalDownloading > 0)
                                ? (completedDownloading / totalDownloading)
                                      .clamp(0.0, 1.0)
                                : null,
                            backgroundColor: Colors.grey.shade300,
                            color: const Color(0xFF00695C),
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? Colors.teal.shade800
                                  : Colors.teal.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF00695C),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      completedDownloading == 0
                                          ? 'সার্ভার থেকে ডেটা প্রসেসিং হচ্ছে... অনুগ্রহ করে অপেক্ষা করুন'
                                          : 'ডাউনলোড সম্পন্ন: ${BanglaHelper.toBanglaDigits(completedDownloading.toString())}/${BanglaHelper.toBanglaDigits(totalDownloading.toString())} টি এলাকা • বাকি: ${BanglaHelper.toBanglaDigits(remainingDownloading.toString())} টি',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.tealAccent
                                            : Colors.teal.shade900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      downloadState.currentProcessingArea,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // 🔴 প্রথম ক্লিকেই তাৎক্ষণিক বাতিল বাটন
                              InkWell(
                                onTap: () {
                                  VoterDownloadManager.instance
                                      .cancelDownload();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ডাউনলোড বাতিল করা হয়েছে।'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'বাতিল',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            // সিলেক্ট অল (সম্পূর্ণ ৩৭৪ টির সাথে ১০০% নিখুঁত ম্যাচ)
            Row(
              children: [
                Checkbox(
                  value: isAllSelected,
                  activeColor: const Color(0xFF00695C),
                  onChanged: (val) =>
                      _toggleSelectAll(val ?? false, allUniqueAreas),
                ),
                Expanded(
                  child: Text(
                    isAllSelected
                        ? 'সবগুলো এলাকা নির্বাচিত (${BanglaHelper.toBanglaDigits(totalCandidateAreas.toString())} টি)'
                        : 'সবগুলো একসাথে নির্বাচন (${BanglaHelper.toBanglaDigits(totalCandidateAreas.toString())} টি)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_selectedAreaKeys.isNotEmpty)
                  TextButton(
                    onPressed: () => _toggleSelectAll(false, allUniqueAreas),
                    child: const Text(
                      'বাতিল',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 1),

            // 🔴 এলাকা তালিকা (এটি আলাদা থাকায় ডাউনলোড চলাকালীন স্ক্রিন কখনোই আটকে যাবে না)
            Expanded(
              child: unionGroups.isEmpty
                  ? const Center(
                      child: Text('কোনো বরাদ্দকৃত এলাকা পাওয়া যায়নি!'),
                    )
                  : ListView.builder(
                      itemCount: unionGroups.entries.length,
                      itemBuilder: (ctx, index) {
                        final entry = unionGroups.entries.elementAt(index);
                        final unionTitle = entry.key;
                        final areas = entry.value;

                        final Set<String> activeSavedSet = {
                          ..._alreadyDownloadedAreas,
                          ...VoterDownloadManager
                              .instance
                              .progressNotifier
                              .value
                              .savedAreaNames,
                        };

                        final bool isUnionAllSelected = areas.every(
                          (item) =>
                              _selectedAreaKeys.contains(_getUniqueKey(item)),
                        );
                        final int unionSavedCount = areas
                            .where((a) => activeSavedSet.contains(a.areaName))
                            .length;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          elevation: 0.5,
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            leading: Checkbox(
                              value: isUnionAllSelected,
                              activeColor: const Color(0xFF00695C),
                              onChanged: (val) =>
                                  _toggleUnion(areas, val ?? false),
                            ),
                            title: Text(
                              unionTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'সংরক্ষিত: ${BanglaHelper.toBanglaDigits(unionSavedCount.toString())}/${BanglaHelper.toBanglaDigits(areas.length.toString())}',
                              style: TextStyle(
                                fontSize: 11,
                                color: unionSavedCount == areas.length
                                    ? Colors.green.shade700
                                    : (isDark
                                          ? Colors.white60
                                          : Colors.black54),
                              ),
                            ),
                            children: areas.map((areaItem) {
                              final areaKey = _getUniqueKey(areaItem);
                              final isAreaChecked = _selectedAreaKeys.contains(
                                areaKey,
                              );
                              final isSaved = activeSavedSet.contains(
                                areaItem.areaName,
                              );

                              final isCurrentlyProcessing =
                                  _updatingAreaName == areaItem.areaName;

                              final screenWidth = MediaQuery.of(context)
                                  .size
                                  .width;

                              return Container(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  leading: Checkbox(
                                    value: isAreaChecked,
                                    activeColor: const Color(0xFF00695C),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedAreaKeys.add(areaKey);
                                        } else {
                                          _selectedAreaKeys.remove(areaKey);
                                        }
                                      });
                                    },
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          areaItem.areaName,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSaved
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (areaItem.totalVoters > 0 &&
                                          screenWidth > 330)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            right: 4,
                                          ),
                                          child: Text(
                                            '(${BanglaHelper.toBanglaDigits(areaItem.totalVoters.toString())} জন)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCurrentlyProcessing)
                                        const Text(
                                          '⏳ সিঙ্ক...',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      else if (isSaved) ...[
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.sync,
                                            color: Color(0xFF00695C),
                                            size: 20,
                                          ),
                                          tooltip: 'আপডেট',
                                          onPressed: () =>
                                              _reSyncSingleAreaAction(areaItem),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          tooltip: 'মুছুন',
                                          onPressed: () =>
                                              _confirmDeleteSingleArea(
                                                areaItem.areaName,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),

            // 🔴 নিচের বাটন বার (ValueListenableBuilder দিয়ে সুরক্ষিত)
            ValueListenableBuilder<DownloadProgressState>(
              valueListenable: VoterDownloadManager.instance.progressNotifier,
              builder: (context, downloadState, _) {
                final bool isDownloading =
                    downloadState.status == DownloadStatus.running;

                final Set<String> activeSavedAreas = {
                  ..._alreadyDownloadedAreas,
                  ...downloadState.savedAreaNames,
                };

                int savedSelectedCount = allUniqueAreas
                    .where(
                      (w) =>
                          _selectedAreaKeys.contains(_getUniqueKey(w)) &&
                          activeSavedAreas.contains(w.areaName.trim()),
                    )
                    .length;

                int unsavedSelectedCount = allUniqueAreas
                    .where(
                      (w) =>
                          _selectedAreaKeys.contains(_getUniqueKey(w)) &&
                          !activeSavedAreas.contains(w.areaName.trim()),
                    )
                    .length;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _selectedAreaKeys.isEmpty
                      ? SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _navigateToHome,
                            icon: const Icon(
                              Icons.home_outlined,
                              color: Color(0xFF004D40),
                              size: 20,
                            ),
                            label: const Text(
                              'হোম পেজে যান',
                              style: TextStyle(
                                color: Color(0xFF004D40),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF004D40),
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _navigateToHome,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF004D40),
                                  ),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.home,
                                  color: Color(0xFF004D40),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 🔴 টিক দিয়ে একসাথে দ্রুত ডিলিট বাটন
                            if (savedSelectedCount > 0) ...[
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : () => _startBatchDelete(
                                            allUniqueAreas,
                                            activeSavedAreas,
                                          ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 15,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'মুছুন (${BanglaHelper.toBanglaDigits(savedSelectedCount.toString())})',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : () => _startDownloadOrUpdate(
                                            allUniqueAreas,
                                            isUpdate: true,
                                          ),
                                    icon: const Icon(
                                      Icons.sync,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'আপডেট (${BanglaHelper.toBanglaDigits(savedSelectedCount.toString())})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],

                            if (unsavedSelectedCount > 0)
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : () => _startDownloadOrUpdate(
                                            allUniqueAreas,
                                            isUpdate: false,
                                          ),
                                    icon: isDownloading
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_download,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        isDownloading
                                            ? 'সিঙ্ক হচ্ছে...'
                                            : 'ডাউনলোড (${BanglaHelper.toBanglaDigits(unsavedSelectedCount.toString())})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE11D48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
