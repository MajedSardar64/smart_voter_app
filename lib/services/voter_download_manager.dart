import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/candidate.dart';
import '../models/voter.dart';
import 'api_service.dart';
import 'db_service.dart';

enum DownloadStatus { idle, running, completed, error }

class DownloadProgressState {
  final DownloadStatus status;
  final int completedAreasCount;
  final int totalAreasCount;
  final int totalVotersSaved;
  final String currentProcessingArea;
  final Set<String> savedAreaNames;
  final String? errorMessage;

  DownloadProgressState({
    required this.status,
    required this.completedAreasCount,
    required this.totalAreasCount,
    required this.totalVotersSaved,
    required this.currentProcessingArea,
    required this.savedAreaNames,
    this.errorMessage,
  });

  double get percent => totalAreasCount > 0
      ? (completedAreasCount / totalAreasCount).clamp(0.0, 1.0)
      : 0.0;
}

class VoterDownloadManager {
  static final VoterDownloadManager instance = VoterDownloadManager._internal();
  VoterDownloadManager._internal();

  final ValueNotifier<DownloadProgressState> progressNotifier = ValueNotifier(
    DownloadProgressState(
      status: DownloadStatus.idle,
      completedAreasCount: 0,
      totalAreasCount: 0,
      totalVotersSaved: 0,
      currentProcessingArea: '',
      savedAreaNames: {},
    ),
  );

  bool _isProcessing = false;
  bool _isCancelled = false;

  void cancelDownload() {
    if (!_isProcessing) return;
    _isCancelled = true;
    _isProcessing = false;

    progressNotifier.value = DownloadProgressState(
      status: DownloadStatus.idle,
      completedAreasCount: progressNotifier.value.completedAreasCount,
      totalAreasCount: progressNotifier.value.totalAreasCount,
      totalVotersSaved: progressNotifier.value.totalVotersSaved,
      currentProcessingArea: '',
      savedAreaNames: progressNotifier.value.savedAreaNames,
      errorMessage: 'ডাউনলোড বাতিল করা হয়েছে।',
    );
  }

  Future<void> syncWithDatabase() async {
    try {
      final List<String> areas = await DBService.instance.getDownloadedAreas();
      final int votersCount = await DBService.instance.getSearchCount();
      final Set<String> savedSet = areas.toSet();

      progressNotifier.value = DownloadProgressState(
        status: _isProcessing ? DownloadStatus.running : DownloadStatus.idle,
        completedAreasCount: savedSet.length,
        totalAreasCount: progressNotifier.value.totalAreasCount > 0
            ? progressNotifier.value.totalAreasCount
            : savedSet.length,
        totalVotersSaved: votersCount,
        currentProcessingArea: progressNotifier.value.currentProcessingArea,
        savedAreaNames: savedSet,
      );
    } catch (e) {
      print('Sync Error: $e');
    }
  }

  Future<bool> reSyncSingleArea(String areaName) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return false;

    try {
      final cand = await AuthService.getActiveCandidate();
      final List<Voter> voters = await VoterApiService.fetchVotersForSingleArea(
        areaName,
        userId: cand?.userId,
      );

      await DBService.instance.deleteAreaVoters(areaName);
      if (voters.isNotEmpty) {
        await DBService.instance.saveVotersFromApi(voters);
      }

      await syncWithDatabase();
      return true;
    } catch (e) {
      print('ReSync Error: $e');
      return false;
    }
  }

  // 🔴 অপ্টিমাইজড ব্যাচ ডাউনলোড ইঞ্জিন (একসাথে ৩-৪টি এলাকা ব্যাচে ডাউনলোড হবে)
  Future<void> startIncrementalDownload(
    List<String> areasToDownload, {
    bool isUpdateMode = false,
  }) async {
    if (_isProcessing || areasToDownload.isEmpty) return;

    _isCancelled = false;

    final Set<String> savedAreas =
        (await DBService.instance.getDownloadedAreas()).toSet();
    int currentSavedVoters = await DBService.instance.getSearchCount();

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.error,
        completedAreasCount: savedAreas.length,
        totalAreasCount: areasToDownload.length,
        totalVotersSaved: currentSavedVoters,
        currentProcessingArea: '',
        savedAreaNames: savedAreas,
        errorMessage:
            'ইন্টারনেট সংযোগ নেই! ইন্টারনেট চালু করে পুনরায় চেষ্টা করুন।',
      );
      return;
    }

    _isProcessing = true;

    final pendingAreas = isUpdateMode
        ? areasToDownload
        : areasToDownload.where((a) => !savedAreas.contains(a)).toList();

    if (pendingAreas.isEmpty) {
      _isProcessing = false;
      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.completed,
        completedAreasCount: savedAreas.length,
        totalAreasCount: areasToDownload.length,
        totalVotersSaved: currentSavedVoters,
        currentProcessingArea: '',
        savedAreaNames: savedAreas,
      );
      return;
    }

    progressNotifier.value = DownloadProgressState(
      status: DownloadStatus.running,
      completedAreasCount: savedAreas.length,
      totalAreasCount: pendingAreas.length,
      totalVotersSaved: currentSavedVoters,
      currentProcessingArea: pendingAreas.first,
      savedAreaNames: savedAreas,
    );

    int failedCount = 0;
    final cand = await AuthService.getActiveCandidate();
    const int batchSize = 4; // ⚡ প্রতি ব্যাচে ৪টি করে এলাকা একবারে ডাউনলোড হবে

    for (int i = 0; i < pendingAreas.length; i += batchSize) {
      if (_isCancelled) break;

      final currentBatch = pendingAreas.sublist(
        i,
        (i + batchSize > pendingAreas.length)
            ? pendingAreas.length
            : i + batchSize,
      );

      final displayArea = currentBatch.length == 1
          ? currentBatch.first
          : '${currentBatch.first} সহ ${currentBatch.length} টি এলাকা';

      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.running,
        completedAreasCount: i,
        totalAreasCount: pendingAreas.length,
        totalVotersSaved: currentSavedVoters,
        currentProcessingArea: displayArea,
        savedAreaNames: savedAreas,
      );

      bool batchSuccess = false;
      int retries = 0;

      while (!batchSuccess && retries < 5 && !_isCancelled) {
        try {
          final List<Voter> voters =
              await VoterApiService.fetchVotersForBatchAreas(
                currentBatch,
                userId: cand?.userId,
              );

          // ডাটা পাওয়ার পরই নিরাপদে ডিলিট ও সেভ
          await DBService.instance.deleteMultipleAreas(currentBatch);

          if (voters.isNotEmpty) {
            await DBService.instance.saveVotersFromApi(voters);
            currentSavedVoters += voters.length;
          }

          savedAreas.addAll(currentBatch);
          batchSuccess = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasDownloadedData', true);

          await Future.delayed(const Duration(milliseconds: 15));
        } catch (e) {
          retries++;
          // স্ক্রিন লক বা কানেকশন ফ্ল্যাকচুয়েশনে অপেক্ষা
          await Future.delayed(Duration(milliseconds: 800 * retries));
        }
      }

      if (!batchSuccess && !_isCancelled) {
        failedCount += currentBatch.length;
      }
    }

    _isProcessing = false;

    if (_isCancelled) {
      _isCancelled = false;
      return;
    }

    currentSavedVoters = await DBService.instance.getSearchCount();

    if (failedCount == pendingAreas.length && pendingAreas.isNotEmpty) {
      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.error,
        completedAreasCount: savedAreas.length,
        totalAreasCount: pendingAreas.length,
        totalVotersSaved: currentSavedVoters,
        currentProcessingArea: '',
        savedAreaNames: savedAreas,
        errorMessage:
            'সার্ভারের সাথে যোগাযোগ করা যায়নি! ইন্টারনেট স্পিড চেক করুন।',
      );
    } else {
      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.completed,
        completedAreasCount: savedAreas.length,
        totalAreasCount: pendingAreas.length,
        totalVotersSaved: currentSavedVoters,
        currentProcessingArea: '',
        savedAreaNames: savedAreas,
      );
    }
  }
}
