import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/candidate.dart';
import '../models/voter.dart';
import '../utils/bangla_helper.dart';
import '../utils/security_helper.dart';

List<Voter> _parseVotersBackground(List<dynamic> list) {
  return list
      .map((item) => Voter.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

class CandidateApiService {
  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "ngrok-skip-browser-warning": "true",
    if (!kIsWeb) "User-Agent": "SmartVoterSecureClient/5.0",
  };

  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    final url = "${AppConfig.apiBaseUrl}?action=candidate_login";

    try {
      final encryptedBodyString = SecurityHelper.encryptWholeRequest({
        "user_id": userId,
        "password": password,
      });

      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encryptedBodyString)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic res = SecurityHelper.decryptWholeResponse(response.body);

        if (res != null &&
            (res['status'] == 'success' || res['success'] == true)) {
          final data = res['data'];
          final cData = data['candidate'];
          final List wardsRaw = data['assigned_wards'] ?? [];

          final candidate = Candidate(
            userId: userId,
            password: '',
            name: cData['name'] ?? '',
            postTitle: cData['post_title'] ?? '',
            electionTitle: cData['election_title'] ?? '',
            electionType: cData['election_type'] ?? 'জাতীয় সংসদ নির্বাচন',
            constituencyOrWard: cData['constituency_or_ward'] ?? '',
            partyName: cData['party_name'] ?? 'স্বতন্ত্র',
            symbolName: cData['symbol_name'] ?? '',
            electionDate: cData['election_date'] ?? '',
            divisionName: cData['division_name'] ?? '',
            districtName: cData['district_name'] ?? '',
            upazilaName: cData['upazila_name'] ?? '',
            totalVoters:
                int.tryParse(cData['total_voters']?.toString() ?? '0') ?? 0,
            showPollingCenter: cData['show_polling_center'] == null
                ? true
                : (cData['show_polling_center'] == true ||
                      cData['show_polling_center'] == 1 ||
                      cData['show_polling_center'].toString() == '1' ||
                      cData['show_polling_center'].toString() == 'true'),
            candidateImage: cData['candidate_image'],
            symbolImage: cData['symbol_image'],
            bannerImage: cData['banner_image'],
            expiryDate:
                DateTime.tryParse(data['expiry_date'] ?? '') ??
                DateTime(2028, 12, 31),
            assignedWards: wardsRaw
                .map((w) => WardAllocation.fromMap(w))
                .toList(),
          );
          return {'success': true, 'candidate': candidate};
        } else {
          return {
            'success': false,
            'message': res?['message'] ?? 'ইউজার আইডি বা পাসওয়ার্ড ভুল!',
          };
        }
      }
      return {
        'success': false,
        'message': 'সার্ভারের সাথে সংযোগ স্থাপন করা সম্ভব হয়নি।',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'ইন্টারনেট সংযোগ নেই অথবা সার্ভার বন্ধ আছে!',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'সার্ভার রেসপন্স টাইমআউট হয়েছে।'};
    } catch (e) {
      return {
        'success': false,
        'message': 'সার্ভারের সাথে সংযোগ স্থাপন করা সম্ভব হয়নি।',
      };
    }
  }

  static Future<Map<String, dynamic>> refreshProfile(String userId) async {
    final url = "${AppConfig.apiBaseUrl}?action=refresh_candidate_profile";

    try {
      final encryptedBodyString = SecurityHelper.encryptWholeRequest({
        "user_id": userId,
      });

      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encryptedBodyString)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic res = SecurityHelper.decryptWholeResponse(response.body);

        if (res != null &&
            (res['status'] == 'success' || res['success'] == true)) {
          final data = res['data'];
          final cData = data['candidate'];
          final List wardsRaw = data['assigned_wards'] ?? [];

          final candidate = Candidate(
            userId: userId,
            password: '',
            name: cData['name'] ?? '',
            postTitle: cData['post_title'] ?? '',
            electionTitle: cData['election_title'] ?? '',
            electionType: cData['election_type'] ?? 'জাতীয় সংসদ নির্বাচন',
            constituencyOrWard: cData['constituency_or_ward'] ?? '',
            partyName: cData['party_name'] ?? 'স্বতন্ত্র',
            symbolName: cData['symbol_name'] ?? '',
            electionDate: cData['election_date'] ?? '',
            divisionName: cData['division_name'] ?? '',
            districtName: cData['district_name'] ?? '',
            upazilaName: cData['upazila_name'] ?? '',
            totalVoters:
                int.tryParse(cData['total_voters']?.toString() ?? '0') ?? 0,
            showPollingCenter: cData['show_polling_center'] == null
                ? true
                : (cData['show_polling_center'] == true ||
                      cData['show_polling_center'] == 1 ||
                      cData['show_polling_center'].toString() == '1' ||
                      cData['show_polling_center'].toString() == 'true'),
            candidateImage: cData['candidate_image'],
            symbolImage: cData['symbol_image'],
            bannerImage: cData['banner_image'],
            expiryDate:
                DateTime.tryParse(data['expiry_date'] ?? '') ??
                DateTime(2028, 12, 31),
            assignedWards: wardsRaw
                .map((w) => WardAllocation.fromMap(w))
                .toList(),
          );
          return {'success': true, 'candidate': candidate};
        }
      }
    } catch (_) {}
    return {'success': false};
  }
}

class VoterApiService {
  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "ngrok-skip-browser-warning": "true",
    if (!kIsWeb) "User-Agent": "SmartVoterSecureClient/5.0",
  };

  // 🔴 ১টি এলাকা ডাউনলোড
  static Future<List<Voter>> fetchVotersForSingleArea(
    String areaName, {
    String? userId,
  }) async {
    return fetchVotersForBatchAreas([areaName], userId: userId);
  }

  // 🔴 হাই-স্পিড ব্যাচ ডাউনলোড মেথড (একসাথে একাধিক এলাকা নিমিষে ডাউনলোড)
  static Future<List<Voter>> fetchVotersForBatchAreas(
    List<String> areaNames, {
    String? userId,
  }) async {
    if (areaNames.isEmpty) return [];

    final url = "${AppConfig.apiBaseUrl}?action=download_voters";

    String currentUserId = userId ?? '';
    if (currentUserId.isEmpty) {
      final cand = await AuthService.getActiveCandidate();
      currentUserId = cand?.userId ?? '';
    }

    final encryptedBodyString = SecurityHelper.encryptWholeRequest({
      "selected_areas": areaNames,
      "user_id": currentUserId,
    });

    final response = await http
        .post(Uri.parse(url), headers: _headers, body: encryptedBodyString)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final dynamic res = SecurityHelper.decryptWholeResponse(response.body);

      if (res != null &&
          (res['status'] == 'success' || res['success'] == true)) {
        final List list = res['voters'] ?? [];
        return await compute(_parseVotersBackground, list);
      } else {
        throw Exception(res?['message'] ?? 'সার্ভার থেকে সঠিক তথ্য আসেনি');
      }
    } else {
      throw HttpException(
        'সার্ভার রেসপন্স ব্যর্থ (Status: ${response.statusCode})',
      );
    }
  }

  static Future<Map<String, dynamic>> searchVotersOnline({
    required String searchType,
    required String keyword,
    String? ward,
    String? area,
    String? gender,
    String? userId,
    int limit = 200,
    int offset = 0,
  }) async {
    final url = "${AppConfig.apiBaseUrl}?action=search_voters";

    String currentUserId = userId ?? '';
    if (currentUserId.isEmpty) {
      final cand = await AuthService.getActiveCandidate();
      currentUserId = cand?.userId ?? '';
    }

    try {
      final payload = {
        "user_id": currentUserId,
        "search_type": searchType,
        "keyword": keyword,
        if (ward != null && ward != 'সকল') "ward": ward,
        if (area != null && area != 'সকল') "voter_area": area,
        if (gender != null && gender != 'সকল') "gender": gender,
        "limit": limit,
        "offset": offset,
      };

      final encryptedBody = SecurityHelper.encryptWholeRequest(payload);
      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encryptedBody)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic res = SecurityHelper.decryptWholeResponse(response.body);
        if (res != null &&
            (res['status'] == 'success' || res['data'] != null)) {
          final List rawList = res['data'] ?? [];
          final List<Voter> voters = rawList.map((item) {
            return Voter.fromMap(Map<String, dynamic>.from(item));
          }).toList();
          return {'voters': voters, 'count': res['count'] ?? voters.length};
        }
      }
    } catch (e) {
      print('Online search error: $e');
    }
    return {'voters': <Voter>[], 'count': 0};
  }

  // 🔴 অনলাইন ফ্যামিলি সার্চ (মিনিমাম ৫০% ম্যাচিং স্কোর ফিল্টারিং সহ)
  static Future<List<Voter>> searchFamilyOnline(
    Voter voter, {
    String? userId,
  }) async {
    final url = "${AppConfig.apiBaseUrl}?action=search_voters";

    String currentUserId = userId ?? '';
    if (currentUserId.isEmpty) {
      final cand = await AuthService.getActiveCandidate();
      currentUserId = cand?.userId ?? '';
    }

    try {
      final payload = {
        "user_id": currentUserId,
        "search_type": "family",
        "father_name": voter.fatherOrHusband,
        "mother_name": voter.mother,
        "voter_name": voter.name,
        "voter_no": voter.voterNo,
        "voter_address": voter.address,
        "voter_area": voter.area,
        "gender": BanglaHelper.formatGender(voter.gender),
        "limit": 50,
        "offset": 0,
      };

      final encryptedBody = SecurityHelper.encryptWholeRequest(payload);
      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encryptedBody)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic res = SecurityHelper.decryptWholeResponse(response.body);
        if (res != null &&
            (res['status'] == 'success' || res['data'] != null)) {
          final List rawList = res['data'] ?? [];
          return rawList
              .map((item) => Voter.fromMap(Map<String, dynamic>.from(item)))
              .where((v) => v.voterNo != voter.voterNo && v.matchPercent >= 50)
              .toList();
        }
      }
    } catch (e) {
      print('Family search online error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getDashboardStatsOnline(
    String userId,
  ) async {
    final url = "${AppConfig.apiBaseUrl}?action=get_dashboard_stats";

    try {
      final encryptedBody = SecurityHelper.encryptWholeRequest({
        "user_id": userId,
      });
      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encryptedBody)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic res = SecurityHelper.decryptWholeResponse(response.body);
        if (res != null && res['status'] == 'success') {
          return Map<String, dynamic>.from(res['data'] ?? {});
        }
      }
    } catch (e) {
      print('Dashboard stats online error: $e');
    }
    return {};
  }
}
