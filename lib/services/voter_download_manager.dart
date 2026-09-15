import 'dart:async';

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

  // 🔴 প্রথম ক্লিকেই সাথে সাথে বাতিল নিশ্চিতকরণ
  void cancelDownload() {
    _isCancelled = true;
    _isProcessing = false;

    progressNotifier.value = DownloadProgressState(
      status: DownloadStatus.idle,
      completedAreasCount: 0,
      totalAreasCount: 0,
      totalVotersSaved: progressNotifier.value.totalVotersSaved,
      currentProcessingArea: '',
      savedAreaNames: progressNotifier.value.savedAreaNames,
      errorMessage: null,
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

  Future<bool> reSyncSingleArea(String areaName, {String? areaCode}) async {
    try {
      final cand = await AuthService.getActiveCandidate();
      List<Voter>? voters = await VoterApiService.fetchVotersForSingleArea(
        areaName,
        areaCode: areaCode,
        userId: cand?.userId,
      );

      await DBService.instance.deleteAreaVoters(areaName);
      if (voters.isNotEmpty) {
        await DBService.instance.saveVotersFromApi(voters);
      }
      voters = null; // মেমোরি ক্লিয়ার

      await syncWithDatabase();
      return true;
    } catch (e) {
      print('ReSync Error: $e');
      return false;
    }
  }

  // 🔴 দ্রুততম ও মেমোরি-সুরক্ষিত অর্গানাইজড ব্যাচ ডাউনলোড
  Future<void> startOrganizedBatchDownload(
    List<WardAllocation> targets, {
    bool isUpdateMode = false,
  }) async {
    if (targets.isEmpty) return;

    if (_isProcessing) {
      _isProcessing = false;
      await Future.delayed(const Duration(milliseconds: 40));
    }

    _isCancelled = false;
    _isProcessing = true;

    try {
      final Set<String> savedAreas =
          (await DBService.instance.getDownloadedAreas()).toSet();
      int currentSavedVoters = await DBService.instance.getSearchCount();

      final pendingTargets = isUpdateMode
          ? targets
          : targets
                .where((w) => !savedAreas.contains(w.areaName.trim()))
                .toList();

      if (pendingTargets.isEmpty) {
        progressNotifier.value = DownloadProgressState(
          status: DownloadStatus.completed,
          completedAreasCount: targets.length,
          totalAreasCount: targets.length,
          totalVotersSaved: currentSavedVoters,
          currentProcessingArea: '',
          savedAreaNames: savedAreas,
          errorMessage: 'নির্বাচিত এলাকাগুলো ইতিমধ্যে ডাউনলোড করা রয়েছে।',
        );
        return;
      }

      final int totalAreasCount = pendingTargets.length;
      int completedAreasCount = 0;

      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.running,
        completedAreasCount: 0,
        totalAreasCount: totalAreasCount,
        totalVotersSaved: currentSavedVoters,
        currentProcessingArea: 'ডাউনলোড প্রস্তুতি চলছে...',
        savedAreaNames: savedAreas,
      );

      // ইউনিয়ন অনুযায়ী গ্রুপিং
      final Map<String, List<WardAllocation>> unionGroups = {};
      for (var item in pendingTargets) {
        final uKey = item.unionOrPouro.isNotEmpty
            ? item.unionOrPouro
            : 'নির্ধারিত এলাকা';
        unionGroups.putIfAbsent(uKey, () => []).add(item);
      }

      const int maxSubBatchSize = 5;
      final cand = await AuthService.getActiveCandidate();
      int failedBatches = 0;
      int totalBatches = 0;

      for (var entry in unionGroups.entries) {
        if (_isCancelled) break; // 🔴 তাৎক্ষণিক ক্যানসেল ব্রেক

        final unionTitle = entry.key;
        final unionAreas = entry.value;

        for (int i = 0; i < unionAreas.length; i += maxSubBatchSize) {
          if (_isCancelled) break; // 🔴 তাৎক্ষণিক ক্যানসেল ব্রেক
          totalBatches++;

          final subBatch = unionAreas.sublist(
            i,
            (i + maxSubBatchSize > unionAreas.length)
                ? unionAreas.length
                : i + maxSubBatchSize,
          );

          final subBatchAreaNames = subBatch.map((w) => w.areaName).toList();
          final subBatchAreaCodes = subBatch
              .map((w) => w.areaCode)
              .where((c) => c.isNotEmpty)
              .toList();

          final batchNum = (i ~/ maxSubBatchSize) + 1;
          final totalUnionBatches =
              ((unionAreas.length - 1) ~/ maxSubBatchSize) + 1;
          final batchDisplay = totalUnionBatches > 1
              ? '$unionTitle (ব্যাচ $batchNum/$totalUnionBatches)'
              : unionTitle;

          if (_isCancelled) break;

          progressNotifier.value = DownloadProgressState(
            status: DownloadStatus.running,
            completedAreasCount: completedAreasCount,
            totalAreasCount: totalAreasCount,
            totalVotersSaved: currentSavedVoters,
            currentProcessingArea: batchDisplay,
            savedAreaNames: savedAreas,
          );

          bool batchSuccess = false;
          int retries = 0;

          while (!batchSuccess && retries < 3 && !_isCancelled) {
            try {
              if (_isCancelled) break;

              List<Voter>? voters = await VoterApiService.fetchVotersForBatch(
                subBatchAreaNames,
                areaCodes: subBatchAreaCodes,
                userId: cand?.userId,
              );

              // 🔴 নেটওয়ার্ক কল শেষ হওয়ার ঠিক পরপরই ক্যানসেল যাচাই
              if (_isCancelled) {
                voters = null;
                break;
              }

              await DBService.instance.deleteMultipleAreas(subBatchAreaNames);

              if (voters != null && voters.isNotEmpty) {
                await DBService.instance.saveVotersFromApi(voters);
                currentSavedVoters += voters.length;
              }

              voters = null; // 🔴 র‍্যাম থেকে নাল করে মেমোরি ক্লিয়ার

              for (var a in subBatchAreaNames) {
                savedAreas.add(a.trim());
              }

              completedAreasCount += subBatch.length;
              batchSuccess = true;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hasDownloadedData', true);

              // UI ফ্রেমকে মসৃণভাবে চলার সুযোগ দেওয়া (৫০ms থ্রেড ইয়েল্ড)
              await Future.delayed(const Duration(milliseconds: 50));
            } catch (e) {
              retries++;
              await Future.delayed(Duration(milliseconds: 500 * retries));
            }
          }

          if (!batchSuccess && !_isCancelled) {
            failedBatches++;
          }

          if (_isCancelled) break;

          progressNotifier.value = DownloadProgressState(
            status: DownloadStatus.running,
            completedAreasCount: completedAreasCount,
            totalAreasCount: totalAreasCount,
            totalVotersSaved: currentSavedVoters,
            currentProcessingArea: batchDisplay,
            savedAreaNames: savedAreas,
          );
        }
      }

      // 🔴 ইউজার বাতিল করলে কোনো এরর না দিয়ে সাথে সাথে আইডিলে ফিরে যাওয়া
      if (_isCancelled) {
        _isProcessing = false;
        _isCancelled = false;
        progressNotifier.value = DownloadProgressState(
          status: DownloadStatus.idle,
          completedAreasCount: 0,
          totalAreasCount: 0,
          totalVotersSaved: currentSavedVoters,
          currentProcessingArea: '',
          savedAreaNames: savedAreas,
          errorMessage: null,
        );
        return;
      }

      currentSavedVoters = await DBService.instance.getSearchCount();

      if (failedBatches == totalBatches && totalBatches > 0) {
        progressNotifier.value = DownloadProgressState(
          status: DownloadStatus.error,
          completedAreasCount: savedAreas.length,
          totalAreasCount: totalAreasCount,
          totalVotersSaved: currentSavedVoters,
          currentProcessingArea: '',
          savedAreaNames: savedAreas,
          errorMessage: 'সার্ভারের সাথে যোগাযোগ করা যায়নি! ইন্টারনেট চেক করুন।',
        );
      } else {
        progressNotifier.value = DownloadProgressState(
          status: DownloadStatus.completed,
          completedAreasCount: totalAreasCount,
          totalAreasCount: totalAreasCount,
          totalVotersSaved: currentSavedVoters,
          currentProcessingArea: '',
          savedAreaNames: savedAreas,
        );
      }
    } catch (e) {
      progressNotifier.value = DownloadProgressState(
        status: DownloadStatus.error,
        completedAreasCount: 0,
        totalAreasCount: targets.length,
        totalVotersSaved: 0,
        currentProcessingArea: '',
        savedAreaNames: {},
        errorMessage: 'ডাউনলোড ত্রুটি: $e',
      );
    } finally {
      _isProcessing = false;
    }
  }
}
