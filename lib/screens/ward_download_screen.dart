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
  final Set<String> _selectedAreas = {};
  List<String> _alreadyDownloadedAreas = [];
  bool _isRefreshingAreas = false;
  String? _updatingAreaName;

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
    final state = VoterDownloadManager.instance.progressNotifier.value;
    if (state.status == DownloadStatus.completed) {
      if (mounted && _selectedAreas.isNotEmpty) {
        setState(() {
          _selectedAreas.clear();
        });
      }
    }
  }

  void _initDataAndSyncOnline() async {
    if (_candidate == null) {
      _candidate = await AuthService.getActiveCandidate();
    }

    await VoterDownloadManager.instance.syncWithDatabase();
    final downloaded = await DBService.instance.getDownloadedAreas();

    if (!mounted) return;
    setState(() {
      _alreadyDownloadedAreas = downloaded;
    });

    // 🔴 অটো রিলোড বন্ধ করা হলো (ব্যবহারকারী ম্যানুয়ালি ক্লিক করলে তবেই রিলোড হবে)
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

  void _reSyncSingleAreaAction(String areaName) async {
    setState(() => _updatingAreaName = areaName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$areaName" এলাকার ডাটা সার্ভার থেকে আপডেট হচ্ছে...'),
        duration: const Duration(seconds: 2),
      ),
    );

    bool ok = await VoterDownloadManager.instance.reSyncSingleArea(areaName);
    final downloaded = await DBService.instance.getDownloadedAreas();

    if (!mounted) return;
    setState(() {
      _alreadyDownloadedAreas = downloaded;
      _updatingAreaName = null;
      _selectedAreas.remove(areaName);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'সফলভাবে "$areaName" এলাকার নতুন তথ্য আপডেট হয়েছে!'
              : 'আপডেট ব্যর্থ হয়েছে! ইন্টারনেট চেক করুন।',
        ),
        backgroundColor: ok ? const Color(0xFF00695C) : Colors.red,
      ),
    );
  }

  void _toggleSelectAll(bool selectAll) {
    if (_candidate == null) return;
    setState(() {
      if (selectAll) {
        for (var w in _candidate!.assignedWards) {
          _selectedAreas.add(w.areaName);
        }
      } else {
        _selectedAreas.clear();
      }
    });
  }

  void _toggleUnion(List<WardAllocation> unionWards, bool isSelected) {
    setState(() {
      for (var w in unionWards) {
        if (isSelected) {
          _selectedAreas.add(w.areaName);
        } else {
          _selectedAreas.remove(w.areaName);
        }
      }
    });
  }

  // 🔴 লাইভ অ্যানিমেশন ও কাউন্টার সহ এলাকা মুছে ফেলা
  void _startBatchDelete() async {
    final savedSelected = _selectedAreas
        .where((a) => _alreadyDownloadedAreas.contains(a))
        .toList();

    if (savedSelected.isEmpty) return;

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
          'নির্বাচিত ${BanglaHelper.toBanglaDigits(savedSelected.length.toString())} টি এলাকার সমস্ত ভোটার তথ্য ফোন থেকে মুছে ফেলতে চান?',
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

    // 🔴 লাইভ প্রগ্রেস অ্যানিমেশন ডায়ালগ
    int completedCount = 0;
    String currentDeletingArea = savedSelected.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const CircularProgressIndicator(color: Colors.red),
                const SizedBox(height: 18),
                Text(
                  'মুছে ফেলা হচ্ছে (${BanglaHelper.toBanglaDigits(completedCount.toString())}/${BanglaHelper.toBanglaDigits(savedSelected.length.toString())})...',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentDeletingArea,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );

    // একে একে এলাকা ডিলিট ও লাইভ কাউন্টার আপডেট
    for (int i = 0; i < savedSelected.length; i++) {
      currentDeletingArea = savedSelected[i];
      await DBService.instance.deleteAreaVoters(currentDeletingArea);
      completedCount = i + 1;
      await Future.delayed(
        const Duration(milliseconds: 120),
      ); // মসৃণ অ্যানিমেশন
    }

    await VoterDownloadManager.instance.syncWithDatabase();
    final downloaded = await DBService.instance.getDownloadedAreas();

    if (!mounted) return;
    Navigator.pop(context); // প্রগ্রেস ডায়ালগ বন্ধ করা

    setState(() {
      _alreadyDownloadedAreas = downloaded;
      _selectedAreas.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'সফলভাবে ${BanglaHelper.toBanglaDigits(savedSelected.length.toString())} টি এলাকার তথ্য মুছে ফেলা হয়েছে!',
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
                _selectedAreas.remove(areaName);
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('মুছুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startDownloadOrUpdate({bool isUpdate = false}) async {
    if (_selectedAreas.isEmpty) return;

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

    final targets = _selectedAreas.toList();

    setState(() {
      _selectedAreas.clear();
    });

    VoterDownloadManager.instance.startIncrementalDownload(
      targets,
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
        border: Border.all(color: const Color(0xFF004D40).withOpacity(0.25)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_candidate == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00695C)),
        ),
      );
    }

    final Map<String, List<WardAllocation>> unionGroups = {};
    for (var w in _candidate!.assignedWards) {
      String groupKey = w.unionOrPouro.isNotEmpty
          ? w.unionOrPouro
          : 'নির্ধারিত এলাকা';
      unionGroups.putIfAbsent(groupKey, () => []).add(w);
    }

    final int totalCandidateAreas = _candidate!.assignedWards.length;
    final bool isAllSelected =
        _selectedAreas.length == totalCandidateAreas && totalCandidateAreas > 0;

    final geo = BanglaHelper.getGeoHierarchyFromStorage(_candidate);

    return ValueListenableBuilder<DownloadProgressState>(
      valueListenable: VoterDownloadManager.instance.progressNotifier,
      builder: (context, downloadState, _) {
        final bool isDownloading =
            downloadState.status == DownloadStatus.running;

        final Set<String> savedAreas = {
          ..._alreadyDownloadedAreas,
          ...downloadState.savedAreaNames,
        };

        int realSavedCount = _candidate!.assignedWards
            .where((w) => savedAreas.contains(w.areaName))
            .length;
        int realPendingCount = totalCandidateAreas - realSavedCount;
        if (realPendingCount < 0) realPendingCount = 0;

        int savedSelectedCount = _selectedAreas
            .where((a) => savedAreas.contains(a))
            .length;
        int unsavedSelectedCount = _selectedAreas
            .where((a) => !savedAreas.contains(a))
            .length;

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
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 6.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF004D40),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF004D40),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'প্রশাসনিক অঞ্চল:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF004D40),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _candidate!.constituencyOrWard,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
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
                      if (geo['localUnits']!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          'পৌরসভা/ইউনিয়ন: ${geo['localUnits']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                Container(
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
                      if (isDownloading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: downloadState.percent > 0
                                ? downloadState.percent
                                : null,
                            backgroundColor: Colors.grey.shade300,
                            color: const Color(0xFF00695C),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'প্রসেসিং হচ্ছে: ${downloadState.currentProcessingArea}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isAllSelected,
                        activeColor: const Color(0xFF00695C),
                        onChanged: isDownloading
                            ? null
                            : (val) => _toggleSelectAll(val ?? false),
                      ),
                      Expanded(
                        child: Text(
                          isAllSelected
                              ? 'সবগুলো এলাকা নির্বাচিত'
                              : 'সবগুলো একসাথে নির্বাচন',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (_selectedAreas.isNotEmpty && !isDownloading)
                        TextButton(
                          onPressed: () => _toggleSelectAll(false),
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
                ),
                const Divider(height: 1),

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

                            final bool isUnionAllSelected = areas.every(
                              (item) => _selectedAreas.contains(item.areaName),
                            );
                            final int unionSavedCount = areas
                                .where((a) => savedAreas.contains(a.areaName))
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
                                  onChanged: isDownloading
                                      ? null
                                      : (val) =>
                                            _toggleUnion(areas, val ?? false),
                                ),
                                title: Text(
                                  unionTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
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
                                  final isAreaChecked = _selectedAreas.contains(
                                    areaItem.areaName,
                                  );
                                  final isSaved = savedAreas.contains(
                                    areaItem.areaName,
                                  );
                                  final isCurrentlyProcessing =
                                      downloadState.currentProcessingArea ==
                                          areaItem.areaName ||
                                      _updatingAreaName == areaItem.areaName;

                                  return Container(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    child: ListTile(
                                      dense: true,
                                      leading: Checkbox(
                                        value: isAreaChecked,
                                        activeColor: const Color(0xFF00695C),
                                        onChanged: isDownloading
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedAreas.add(
                                                      areaItem.areaName,
                                                    );
                                                  } else {
                                                    _selectedAreas.remove(
                                                      areaItem.areaName,
                                                    );
                                                  }
                                                });
                                              },
                                      ),
                                      title: Text(
                                        areaItem.areaName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSaved
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrentlyProcessing)
                                            const Text(
                                              '⏳ সিঙ্ক হচ্ছে...',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          else if (isSaved) ...[
                                            IconButton(
                                              icon: const Icon(
                                                Icons.sync,
                                                color: Color(0xFF00695C),
                                                size: 19,
                                              ),
                                              tooltip: 'আপডেট করুন',
                                              onPressed: isDownloading
                                                  ? null
                                                  : () =>
                                                        _reSyncSingleAreaAction(
                                                          areaItem.areaName,
                                                        ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              tooltip: 'মুছুন',
                                              onPressed: isDownloading
                                                  ? null
                                                  : () =>
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

                // বাটন: শুধুমাত্র এলাকা সিলেক্ট থাকলে দেখাবে
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _selectedAreas.isEmpty
                      ? SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _navigateToHome,
                            icon: const Icon(
                              Icons.home_outlined,
                              color: Color(0xFF004D40),
                              size: 21,
                            ),
                            label: const Text(
                              'হোম পেজে যান',
                              style: TextStyle(
                                color: Color(0xFF004D40),
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
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
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 48,
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
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            if (savedSelectedCount > 0) ...[
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : _startBatchDelete,
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'মুছুন (${BanglaHelper.toBanglaDigits(savedSelectedCount.toString())})',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      padding: EdgeInsets.zero,
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
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : () => _startDownloadOrUpdate(
                                            isUpdate: true,
                                          ),
                                    icon: const Icon(
                                      Icons.sync,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'আপডেট (${BanglaHelper.toBanglaDigits(savedSelectedCount.toString())})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      padding: EdgeInsets.zero,
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
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : () => _startDownloadOrUpdate(
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
                                            size: 18,
                                          ),
                                    label: Text(
                                      isDownloading
                                          ? 'সিঙ্ক হচ্ছে...'
                                          : 'ডাউনলোড (${BanglaHelper.toBanglaDigits(unsavedSelectedCount.toString())})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _counterBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
