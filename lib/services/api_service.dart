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
    "User-Agent": "SmartVoterSecureClient/4.0",
  };

  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    final url = "${AppConfig.apiBaseUrl}?action=candidate_login";

    try {
      final encryptedBody = SecurityHelper.encryptPayload({
        "user_id": userId,
        "password": password,
      });

      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({
              "payload": encryptedBody,
              "user_id": userId,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        Map<String, dynamic> res =
            (resJson['secure'] == true && resJson['payload'] != null)
            ? SecurityHelper.decryptPayload(resJson['payload'])
            : resJson;

        if (res['status'] == 'success' || res['success'] == true) {
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
            'message': res['message'] ?? 'ইউজার আইডি বা পাসওয়ার্ড ভুল!',
          };
        }
      }
      return {
        'success': false,
        'message': 'সার্ভার রেসপন্স কোড: ${response.statusCode}',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'ইন্টারনেট সংযোগ নেই অথবা সার্ভার বন্ধ আছে!',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'সার্ভার রেসপন্স টাইমআউট হয়েছে।'};
    } catch (e) {
      return {'success': false, 'message': 'কানেকশন ত্রুটি: $e'};
    }
  }

  // প্রার্থীর নতুন এলাকা ও প্রোফাইল সরাসরি রিফ্রেশ
  static Future<Map<String, dynamic>> refreshProfile(String userId) async {
    final url = "${AppConfig.apiBaseUrl}?action=refresh_candidate_profile";

    try {
      final encryptedBody = SecurityHelper.encryptPayload({"user_id": userId});
      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({"payload": encryptedBody, "user_id": userId}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        Map<String, dynamic> res =
            (resJson['secure'] == true && resJson['payload'] != null)
            ? SecurityHelper.decryptPayload(resJson['payload'])
            : resJson;

        if (res['status'] == 'success' || res['success'] == true) {
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
      final encryptedBody = SecurityHelper.encryptPayload({
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
              "User-Agent": "SmartVoterSecureClient/4.0",
            },
            body: jsonEncode({
              "payload": encryptedBody,
              "area_name": areaName,
              "user_id": userId ?? '',
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        Map<String, dynamic> res =
            (resJson['secure'] == true && resJson['payload'] != null)
            ? SecurityHelper.decryptPayload(resJson['payload'])
            : resJson;

        if (res['status'] == 'success' || res['success'] == true) {
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
