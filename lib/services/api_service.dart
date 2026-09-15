import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/candidate.dart';
import '../models/voter.dart';
import '../utils/security_helper.dart';

List<Voter> _parseVotersBackground(List<dynamic> list) {
  return list
      .map((item) => Voter.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

class CandidateApiService {
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.example.smart_voter_app/bengali_ocr',
  );

  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "ngrok-skip-browser-warning": "true",
    if (!kIsWeb) "User-Agent": "SmartVoterSecureClient/5.0",
  };

  // 🔴 ডিভাইসের স্থায়ী আসল হার্ডওয়্যার আইডি (ডাটা ক্লিয়ার করলেও বদলাবে না)
  static Future<String> _getPermanentHardwareId() async {
    final prefs = await SharedPreferences.getInstance();
    String? hardwareId = prefs.getString('permanent_device_hardware_id');

    if (hardwareId != null &&
        hardwareId.isNotEmpty &&
        !hardwareId.startsWith('HW_ANDROID_')) {
      return hardwareId;
    }

    if (kIsWeb) {
      hardwareId = 'WEB_CLIENT';
    } else {
      try {
        final String? nativeId = await _nativeChannel.invokeMethod<String>(
          'getAndroidHardwareId',
        );
        if (nativeId != null &&
            nativeId.trim().isNotEmpty &&
            nativeId != 'UNKNOWN_ANDROID') {
          hardwareId = nativeId.trim();
        }
      } catch (_) {}

      // নেটিভ চ্যানেল না পেলে নিরাপদ সিগনেচার
      if (hardwareId == null || hardwareId.isEmpty) {
        hardwareId =
            'DEV_${Platform.operatingSystem.toUpperCase()}_${Platform.localHostname.hashCode.abs()}';
      }
    }

    await prefs.setString('permanent_device_hardware_id', hardwareId);
    return hardwareId;
  }

  // 🔴 ডিভাইসের আসল পাবলিক ইন্টারনেট আইপি (রাউটার লোকাল আইপি বাইপাস)
  static Future<String> _getClientPublicIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body.trim();
      }
    } catch (_) {}
    return '';
  }

  // 🔴 ফোনের মডেল নাম
  static String _getDeviceModelName() {
    if (kIsWeb) return 'ওয়েব ব্রাউজার (Web)';
    try {
      if (Platform.isAndroid) {
        return 'Android Phone (${Platform.operatingSystemVersion.split(' ')[0]})';
      }
      if (Platform.isIOS) return 'Apple iPhone (iOS)';
    } catch (_) {}
    return 'স্মার্টফোন';
  }

  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    final url = "${AppConfig.apiBaseUrl}?action=candidate_login";

    try {
      final hardwareId = await _getPermanentHardwareId();
      final deviceModel = _getDeviceModelName();
      final publicIp = await _getClientPublicIp();

      final encryptedBodyString = SecurityHelper.encryptWholeRequest({
        "user_id": userId,
        "password": password,
        "device_id": hardwareId,
        "device_model": deviceModel,
        "client_ip": publicIp,
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
      final hardwareId = await _getPermanentHardwareId();
      final deviceModel = _getDeviceModelName();
      final publicIp = await _getClientPublicIp();

      final encryptedBodyString = SecurityHelper.encryptWholeRequest({
        "user_id": userId,
        "device_id": hardwareId,
        "device_model": deviceModel,
        "client_ip": publicIp,
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

  static Future<List<Voter>> fetchVotersForSingleArea(
    String areaName, {
    String? userId,
    String? areaCode,
  }) async {
    return fetchVotersForBatch(
      [areaName],
      areaCodes: (areaCode != null && areaCode.isNotEmpty) ? [areaCode] : [],
      userId: userId,
    );
  }

  static Future<List<Voter>> fetchVotersForBatch(
    List<String> areaNames, {
    List<String> areaCodes = const [],
    String? userId,
  }) async {
    if (areaNames.isEmpty && areaCodes.isEmpty) return [];

    final url = "${AppConfig.apiBaseUrl}?action=download_voters";

    String currentUserId = userId ?? '';
    if (currentUserId.isEmpty) {
      final cand = await AuthService.getActiveCandidate();
      currentUserId = cand?.userId ?? '';
    }

    final encryptedBodyString = SecurityHelper.encryptWholeRequest({
      "area_name": areaNames.isNotEmpty ? areaNames.first : '',
      "selected_areas": areaNames,
      "selected_codes": areaCodes,
      "user_id": currentUserId,
    });

    final response = await http
        .post(Uri.parse(url), headers: _headers, body: encryptedBodyString)
        .timeout(const Duration(seconds: 45));

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
        "gender": voter.gender,
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
