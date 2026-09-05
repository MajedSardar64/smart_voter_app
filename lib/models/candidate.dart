import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/offline_image_service.dart';

class WardAllocation {
  final String divisionName;
  final String districtName;
  final String upazilaName;
  final String unionOrPouro;
  final String wardNo;
  final String areaName;
  final int totalVoters;

  WardAllocation({
    this.divisionName = '',
    this.districtName = '',
    this.upazilaName = '',
    required this.unionOrPouro,
    required this.wardNo,
    required this.areaName,
    required this.totalVoters,
  });

  Map<String, dynamic> toMap() => {
    'divisionName': divisionName,
    'districtName': districtName,
    'upazilaName': upazilaName,
    'unionOrPouro': unionOrPouro,
    'wardNo': wardNo,
    'areaName': areaName,
    'totalVoters': totalVoters,
  };

  factory WardAllocation.fromMap(dynamic map) {
    if (map is! Map) {
      return WardAllocation(
        divisionName: '',
        districtName: '',
        upazilaName: '',
        unionOrPouro: '',
        wardNo: '',
        areaName: '',
        totalVoters: 0,
      );
    }
    return WardAllocation(
      divisionName: map['divisionName']?.toString() ?? '',
      districtName: map['districtName']?.toString() ?? '',
      upazilaName: map['upazilaName']?.toString() ?? '',
      unionOrPouro: map['unionOrPouro']?.toString() ?? '',
      wardNo: map['wardNo']?.toString() ?? '',
      areaName: map['areaName']?.toString() ?? '',
      totalVoters: int.tryParse(map['totalVoters']?.toString() ?? '0') ?? 0,
    );
  }
}

class Candidate {
  final String userId;
  final String password;
  final String name;
  final String postTitle;
  final String electionTitle;
  final String electionType;
  final String constituencyOrWard;
  final String partyName;
  final String symbolName;
  final String electionDate;
  final String divisionName;
  final String districtName;
  final String upazilaName;
  final int totalVoters;
  final bool showPollingCenter; // 🔴 নতুন ফ্ল্যাগ
  final String? candidateImage;
  final String? symbolImage;
  final String? bannerImage;
  final DateTime expiryDate;
  final List<WardAllocation> assignedWards;

  Candidate({
    required this.userId,
    required this.password,
    required this.name,
    required this.postTitle,
    required this.electionTitle,
    this.electionType = 'জাতীয় সংসদ নির্বাচন',
    this.constituencyOrWard = '',
    this.partyName = 'স্বতন্ত্র',
    required this.symbolName,
    required this.electionDate,
    this.divisionName = '',
    this.districtName = '',
    this.upazilaName = '',
    this.totalVoters = 0,
    this.showPollingCenter = true,
    this.candidateImage,
    this.symbolImage,
    this.bannerImage,
    required this.expiryDate,
    required this.assignedWards,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'postTitle': postTitle,
    'electionTitle': electionTitle,
    'electionType': electionType,
    'constituencyOrWard': constituencyOrWard,
    'partyName': partyName,
    'symbolName': symbolName,
    'electionDate': electionDate,
    'divisionName': divisionName,
    'districtName': districtName,
    'upazilaName': upazilaName,
    'total_voters': totalVoters,
    'show_polling_center': showPollingCenter ? 1 : 0,
    'candidateImage': candidateImage,
    'symbolImage': symbolImage,
    'bannerImage': bannerImage,
    'expiryDate': expiryDate.toIso8601String(),
    'assignedWards': assignedWards.map((w) => w.toMap()).toList(),
  };

  factory Candidate.fromMap(dynamic map) {
    if (map is! Map) {
      return Candidate(
        userId: '',
        password: '',
        name: '',
        postTitle: '',
        electionTitle: '',
        electionType: 'জাতীয় সংসদ নির্বাচন',
        constituencyOrWard: '',
        partyName: 'স্বতন্ত্র',
        symbolName: '',
        electionDate: '',
        divisionName: '',
        districtName: '',
        upazilaName: '',
        totalVoters: 0,
        showPollingCenter: true,
        expiryDate: DateTime.now(),
        assignedWards: [],
      );
    }
    final rawList = map['assignedWards'];
    List<WardAllocation> wards = [];
    if (rawList is List) {
      wards = rawList.map((w) => WardAllocation.fromMap(w)).toList();
    }
    return Candidate(
      userId: map['userId']?.toString() ?? '',
      password: '',
      name: map['name']?.toString() ?? '',
      postTitle: map['postTitle']?.toString() ?? '',
      electionTitle: map['electionTitle'] ?? '',
      electionType: map['electionType']?.toString() ?? 'জাতীয় সংসদ নির্বাচন',
      constituencyOrWard: map['constituencyOrWard']?.toString() ?? '',
      partyName: map['partyName']?.toString() ?? 'স্বতন্ত্র',
      symbolName: map['symbolName'] ?? '',
      electionDate: map['electionDate'] ?? '',
      divisionName: map['divisionName']?.toString() ?? '',
      districtName: map['districtName']?.toString() ?? '',
      upazilaName: map['upazilaName']?.toString() ?? '',
      totalVoters: int.tryParse(map['total_voters']?.toString() ?? '0') ?? 0,
      showPollingCenter: map['show_polling_center'] == null
          ? true
          : (map['show_polling_center'] == 1 ||
                map['show_polling_center'] == true ||
                map['show_polling_center'].toString() == '1' ||
                map['show_polling_center'].toString() == 'true'),
      candidateImage: map['candidateImage']?.toString(),
      symbolImage: map['symbolImage']?.toString(),
      bannerImage: map['bannerImage']?.toString(),
      expiryDate:
          DateTime.tryParse(map['expiryDate']?.toString() ?? '') ??
          DateTime(2028, 12, 31),
      assignedWards: wards,
    );
  }
}

class AuthService {
  static final ValueNotifier<Candidate?> activeCandidateNotifier =
      ValueNotifier(null);

  static Future<Map<String, dynamic>> processLogin(
    String userId,
    String password,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String localCandidateKey = 'saved_candidate_$userId';
    final String localPasswordKey = 'saved_password_$userId';

    if (prefs.containsKey(localCandidateKey)) {
      final savedPass = prefs.getString(localPasswordKey);
      if (savedPass != password) {
        return {'success': false, 'message': 'পাসওয়ার্ড সঠিক নয়!'};
      }

      final candidateJson = prefs.getString(localCandidateKey);
      if (candidateJson != null) {
        final localCandidate = Candidate.fromMap(jsonDecode(candidateJson));

        if (DateTime.now().isAfter(localCandidate.expiryDate)) {
          final connectivity = await Connectivity().checkConnectivity();
          if (connectivity.contains(ConnectivityResult.none)) {
            return {
              'success': false,
              'message': 'আপনার লোকাল অ্যাকাউন্টের মেয়াদ শেষ হয়েছে। রিনিউ যাচাই করতে ইন্টারনেট সংযোগ দিয়ে লগইন করুন।',
            };
          }

          final serverResult = await CandidateApiService.login(
            userId,
            password,
          );
          if (serverResult['success'] == true) {
            Candidate renewedCandidate = serverResult['candidate'];

            if (DateTime.now().isAfter(renewedCandidate.expiryDate)) {
              return {
                'success': false,
                'message': 'অ্যাডমিন প্যানেল থেকে এখনও মেয়াদ বাড়ানো হয়নি!',
              };
            }

            final updatedMap = renewedCandidate.toMap();
            await prefs.setString(localCandidateKey, jsonEncode(updatedMap));
            await prefs.setString('active_candidate', jsonEncode(updatedMap));
            activeCandidateNotifier.value = renewedCandidate;

            return {'success': true, 'candidate': renewedCandidate};
          } else {
            return {
              'success': false,
              'message': serverResult['message'] ?? 'রিনিউ যাচাই ব্যর্থ হয়েছে!',
            };
          }
        }

        await prefs.setString('active_candidate', candidateJson);
        activeCandidateNotifier.value = localCandidate;
        return {'success': true, 'candidate': localCandidate};
      }
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return {
        'success': false,
        'message': 'প্রথমবার লগইন করার জন্য ইন্টারনেট সংযোগ আবশ্যক!',
      };
    }

    final result = await CandidateApiService.login(userId, password);
    if (result['success'] == true) {
      Candidate candidate = result['candidate'];

      if (DateTime.now().isAfter(candidate.expiryDate)) {
        return {
          'success': false,
          'message': 'আপনার অ্যাকাউন্টের মেয়াদ শেষ হয়ে গেছে!',
        };
      }

      final localCandImg = await OfflineImageService.downloadAndCacheImage(
        candidate.candidateImage,
        'cand_img',
      );
      final localSymImg = await OfflineImageService.downloadAndCacheImage(
        candidate.symbolImage,
        'sym_img',
      );
      final localBanImg = await OfflineImageService.downloadAndCacheImage(
        candidate.bannerImage,
        'ban_img',
      );

      final offlineCandidate = Candidate(
        userId: candidate.userId,
        password: '',
        name: candidate.name,
        postTitle: candidate.postTitle,
        electionTitle: candidate.electionTitle,
        electionType: candidate.electionType,
        constituencyOrWard: candidate.constituencyOrWard,
        partyName: candidate.partyName,
        symbolName: candidate.symbolName,
        electionDate: candidate.electionDate,
        divisionName: candidate.divisionName,
        districtName: candidate.districtName,
        upazilaName: candidate.upazilaName,
        totalVoters: candidate.totalVoters,
        showPollingCenter: candidate.showPollingCenter,
        candidateImage: localCandImg,
        symbolImage: localSymImg,
        bannerImage: localBanImg,
        expiryDate: candidate.expiryDate,
        assignedWards: candidate.assignedWards,
      );

      final candidateMap = offlineCandidate.toMap();
      await prefs.setString(localCandidateKey, jsonEncode(candidateMap));
      await prefs.setString(localPasswordKey, password);
      await prefs.setString('active_candidate', jsonEncode(candidateMap));
      activeCandidateNotifier.value = offlineCandidate;

      return {'success': true, 'candidate': offlineCandidate};
    } else {
      return {
        'success': false,
        'message': result['message'] ?? 'Login failed.',
      };
    }
  }

  static Future<bool> refreshCandidateOnline() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final currentCandidate = await getActiveCandidate();
      if (currentCandidate == null) return false;

      final result = await CandidateApiService.refreshProfile(
        currentCandidate.userId,
      );
      if (result['success'] == true) {
        Candidate candidate = result['candidate'];

        final localCandImg = await OfflineImageService.downloadAndCacheImage(
          candidate.candidateImage,
          'cand_img',
        );
        final localSymImg = await OfflineImageService.downloadAndCacheImage(
          candidate.symbolImage,
          'sym_img',
        );
        final localBanImg = await OfflineImageService.downloadAndCacheImage(
          candidate.bannerImage,
          'ban_img',
        );

        final updatedOfflineCandidate = Candidate(
          userId: candidate.userId,
          password: '',
          name: candidate.name,
          postTitle: candidate.postTitle,
          electionTitle: candidate.electionTitle,
          electionType: candidate.electionType,
          constituencyOrWard: candidate.constituencyOrWard,
          partyName: candidate.partyName,
          symbolName: candidate.symbolName,
          electionDate: candidate.electionDate,
          divisionName: candidate.divisionName,
          districtName: candidate.districtName,
          upazilaName: candidate.upazilaName,
          totalVoters: candidate.totalVoters,
          showPollingCenter: candidate.showPollingCenter,
          candidateImage: localCandImg,
          symbolImage: localSymImg,
          bannerImage: localBanImg,
          expiryDate: candidate.expiryDate,
          assignedWards: candidate.assignedWards,
        );

        // 🔴 যদি প্যানেল থেকে ভোট কেন্দ্র বন্ধ করা হয়ে থাকে, তবে অফলাইন SQLite ডেটাবেজ থেকেও তাৎক্ষণিক মুছে ফেলা হবে
        if (!kIsWeb && !updatedOfflineCandidate.showPollingCenter) {
          await DBService.instance.clearAllPollingCenters();
        }

        final candidateMap = updatedOfflineCandidate.toMap();
        await prefs.setString(
          'saved_candidate_${candidate.userId}',
          jsonEncode(candidateMap),
        );
        await prefs.setString('active_candidate', jsonEncode(candidateMap));
        activeCandidateNotifier.value = updatedOfflineCandidate;
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<Candidate?> getActiveCandidate() async {
    if (activeCandidateNotifier.value != null) {
      return activeCandidateNotifier.value;
    }
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString('active_candidate');
      if (data != null) {
        final cand = Candidate.fromMap(jsonDecode(data));
        activeCandidateNotifier.value = cand;
        return cand;
      }
    } catch (_) {}
    return null;
  }
}
