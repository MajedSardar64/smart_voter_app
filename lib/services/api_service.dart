import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/candidate.dart';
import '../models/voter.dart';
import '../utils/security_helper.dart';

List<Voter> _parseVotersBackground(List<dynamic> list) {
  return list.map((item) => Voter.fromMap(item)).toList();
}

class CandidateApiService {
  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "ngrok-skip-browser-warning": "true",
    "User-Agent": "SmartVoterSecureClient/5.0",
  };

  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    final url = "${AppConfig.apiBaseUrl}?action=candidate_login";

    try {
      // ১. সম্পূর্ণ রিকোয়েস্ট এনক্রিপ্ট করা
      final encryptedBodyString = SecurityHelper.encryptWholeRequest({
        "user_id": userId,
        "password": password,
      });

      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encryptedBodyString)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        // ২. সার্ভারের ১০০% এনক্রিপ্টেড রেসপন্স সম্পূর্ণ ডিক্রিপ্ট করা
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
          .timeout(const Duration(seconds: 12));

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
  static Future<List<Voter>> fetchVotersForSingleArea(
    String areaName, {
    String? userId,
  }) async {
    final url = "${AppConfig.apiBaseUrl}?action=download_voters";

    try {
      final encryptedBodyString = SecurityHelper.encryptWholeRequest({
        "area_name": areaName,
        "user_id": userId ?? '',
      });

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              "ngrok-skip-browser-warning": "true",
              "User-Agent": "SmartVoterSecureClient/5.0",
            },
            body: encryptedBodyString,
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final dynamic res = SecurityHelper.decryptWholeResponse(response.body);

        if (res != null &&
            (res['status'] == 'success' || res['success'] == true)) {
          final List list = res['voters'] ?? [];
          return await compute(_parseVotersBackground, list);
        }
      }
    } catch (e) {
      print("Area $areaName download error: $e");
    }
    return [];
  }
}
