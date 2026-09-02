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

  @override
  void initState() {
    super.initState();
    _candidate = widget.candidate;
    _initDataAndSyncOnline();
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

    // পেজে ঢুকলে ইন্টারনেট অন থাকলে প্রার্থীর নতুন এলাকা স্বয়ংক্রিয়ভাবে সিঙ্ক করা
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.none)) {
      _manualRefreshAreas(showToast: false);
    }
  }

  // ম্যানুয়াল বাটন দিয়ে প্রার্থীর এলাকা ও প্রোফাইল সার্ভার থেকে রিফ্রেশ করা
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
              'সার্ভার থেকে প্রার্থীর নতুন এলাকা সফলভাবে আপডেট হয়েছে!',
            ),
            backgroundColor: Color(0xFF00695C),
          ),
        );
      }
    } else if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সার্ভারে কানেক্ট করা যায়নি! ইন্টারনেট চেক করুন।'),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (mounted) setState(() => _isRefreshingAreas = false);
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

  void _startBatchDelete() async {
    final savedSelected = _selectedAreas
        .where((a) => _alreadyDownloadedAreas.contains(a))
        .toList();

    if (savedSelected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('নির্বাচিত এলাকাগুলোর মধ্যে কোনো সংরক্ষিত এলাকা নেই!'),
        ),
      );
      return;
    }

    showDialog(
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
          'আপনি কি নির্বাচিত ${BanglaHelper.toBanglaDigits(savedSelected.length.toString())} টি এলাকার সমস্ত ভোটার তথ্য ফোন থেকে মুছে ফেলতে চান? (প্রয়োজনে পরবর্তীতে আবার ডাউনলোড করতে পারবেন)',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('না, বাতিল'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DBService.instance.deleteMultipleAreas(savedSelected);
              await VoterDownloadManager.instance.syncWithDatabase();
              final downloaded = await DBService.instance.getDownloadedAreas();

              if (!mounted) return;
              setState(() {
                _alreadyDownloadedAreas = downloaded;
                _selectedAreas.removeAll(savedSelected);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'সফলভাবে ${BanglaHelper.toBanglaDigits(savedSelected.length.toString())} টি এলাকার তথ্য মুছে ফেলা হয়েছে!',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'হ্যাঁ, মুছে ফেলুন',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
          'আপনি কি "$areaName" এলাকার সমস্ত ভোটার তথ্য ফোন থেকে মুছে ফেলতে চান?',
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

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'সফলভাবে "$areaName" এলাকার তথ্য মুছে ফেলা হয়েছে!',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('মুছুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startStrictDownload() async {
    if (_selectedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('অনুগ্রহ করে অন্তত একটি এলাকা নির্বাচন করুন!'),
        ),
      );
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ইন্টারনেট সংযোগ নেই! ইন্টারনেট চালু করে ডাউনলোড করুন।',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    VoterDownloadManager.instance.startIncrementalDownload(
      _selectedAreas.toList(),
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

    return ValueListenableBuilder<DownloadProgressState>(
      valueListenable: VoterDownloadManager.instance.progressNotifier,
      builder: (context, downloadState, _) {
        final bool isDownloading =
            downloadState.status == DownloadStatus.running;

        final Set<String> savedAreas = {
          ..._alreadyDownloadedAreas,
          ...downloadState.savedAreaNames,
        };

        int pendingCount = _selectedAreas
            .where((a) => !savedAreas.contains(a))
            .length;
        int savedSelectedCount = _selectedAreas
            .where((a) => savedAreas.contains(a))
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('ভোটার এলাকা নির্বাচন ও সিঙ্ক'),
            automaticallyImplyLeading: widget.isFromSettings,
            actions: [
              // লাইভ এলাকা রিফ্রেশ বাটন
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
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeShell()),
                    (route) => false,
                  );
                },
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
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ১. লাইভ স্ট্যাটাস ও এরর কার্ড
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
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
                            '${BanglaHelper.toBanglaDigits(savedAreas.length.toString())} টি',
                            Colors.green.shade700,
                          ),
                          _counterBadge(
                            'বাকি এলাকা',
                            '${BanglaHelper.toBanglaDigits(pendingCount.toString())} টি',
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
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: downloadState.percent > 0
                                ? downloadState.percent
                                : null,
                            backgroundColor: Colors.grey.shade300,
                            color: const Color(0xFF00695C),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ডাউনলোড ও সেভ হচ্ছে: ${downloadState.currentProcessingArea}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ২. নির্বাচন ও বাতিল বার
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isAllSelected,
                            activeColor: const Color(0xFF00695C),
                            onChanged: isDownloading
                                ? null
                                : (val) => _toggleSelectAll(val ?? false),
                          ),
                          Text(
                            isAllSelected
                                ? 'সবগুলো এলাকা নির্বাচন করা হয়েছে'
                                : 'সবগুলো এলাকা একসাথে নির্বাচন করুন',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedAreas.isNotEmpty && !isDownloading)
                        TextButton(
                          onPressed: () => _toggleSelectAll(false),
                          child: const Text(
                            'সব বাতিল',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ৩. এলাকা তালিকা
                Expanded(
                  child: unionGroups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'প্রার্থীর কোনো বরাদ্দকৃত এলাকা পাওয়া যায়নি!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _isRefreshingAreas
                                    ? null
                                    : () =>
                                          _manualRefreshAreas(showToast: true),
                                icon: const Icon(Icons.sync, size: 18),
                                label: const Text(
                                  'সার্ভার থেকে এলাকা সিঙ্ক করুন',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF004D40),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
                              margin: const EdgeInsets.symmetric(vertical: 4),
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
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'সংরক্ষিত: ${BanglaHelper.toBanglaDigits(unionSavedCount.toString())}/${BanglaHelper.toBanglaDigits(areas.length.toString())} এলাকা',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
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
                                      areaItem.areaName;

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
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade700,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '⏳ সেভ হচ্ছে...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          else if (isSaved) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade700,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '✓ সংরক্ষিত',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              tooltip: 'এলাকা মুছে ফেলুন',
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

                // ৪. মাল্টি-অ্যাকশন বাটন বার
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed:
                                (isDownloading || savedSelectedCount == 0)
                                ? null
                                : _startBatchDelete,
                            icon: const Icon(
                              Icons.delete_sweep,
                              color: Colors.red,
                              size: 20,
                            ),
                            label: Text(
                              savedSelectedCount > 0
                                  ? 'মুছুন (${BanglaHelper.toBanglaDigits(savedSelectedCount.toString())})'
                                  : 'মুছে ফেলুন',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: isDownloading
                                ? null
                                : _startStrictDownload,
                            icon: isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_download,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            label: Text(
                              isDownloading
                                  ? 'ডাউনলোড হচ্ছে...'
                                  : 'ডাউনলোড (${BanglaHelper.toBanglaDigits(_selectedAreas.length.toString())})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
