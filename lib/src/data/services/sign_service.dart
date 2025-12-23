import 'dart:async';
import 'dart:convert';

import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SignService {
  SignService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static Uri _endpoint(int agreementId) => Uri.parse(
        'https://api-edo.bek-baraka.uz/api/v1/agreement-signatory/$agreementId/sign/',
      );
  static Uri _rejectEndpoint(int agreementId) => Uri.parse(
        'https://api-edo.bek-baraka.uz/api/v1/agreement-signatory/$agreementId/reject/',
      );

  Future<void> signAgreement({required int agreementId}) async {
    if (agreementId <= 0) {
      throw Exception('Agreement ID noto\'g\'ri.');
    }
    final accessToken = await SecureStorageService.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token topilmadi. Iltimos, tizimga qayta kiring.');
    }
    final pkcs = await SecureStorageService.readMyKey();
    if (pkcs == null || pkcs.isEmpty) {
      throw Exception(
          'Kalit topilmadi. Avval "Kalit olish" jarayonini bajarib ko\'ring.');
    }

    final response = await _client
        .post(
          _endpoint(agreementId),
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
            'Qtype': 'mobile',
            'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
          },
          body: jsonEncode({'pkcs7_64': pkcs}),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint(
        'agreement sign response (${response.statusCode}): ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractMessage(response.body);
      throw Exception(
        message ??
            "Imzolash so'rovi muvaffaqiyatsiz (HTTP ${response.statusCode}).",
      );
    }
  }

  Future<void> rejectAgreement({
    required int agreementId,
    String reason = 'Sababsiz',
  }) async {
    if (agreementId <= 0) {
      throw Exception('Agreement ID noto\'g\'ri.');
    }
    final accessToken = await SecureStorageService.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token topilmadi. Iltimos, tizimga qayta kiring.');
    }
    final pkcs = await SecureStorageService.readMyKey();
    if (pkcs == null || pkcs.isEmpty) {
      throw Exception(
          'Kalit topilmadi. Avval "Kalit olish" jarayonini bajarib ko\'ring.');
    }

    final reasonValue = reason.trim();
    final payload = <String, String>{
      'reason': reasonValue.isEmpty ? 'Sababsiz' : reasonValue,
      'pkcs7_64': pkcs,
    };

    final response = await _client
        .post(
          _rejectEndpoint(agreementId),
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
            'Qtype': 'mobile',
            'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint(
        'agreement reject response (${response.statusCode}): ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractMessage(response.body);
      throw Exception(
        message ??
            "Rad etish so'rovi muvaffaqiyatsiz (HTTP ${response.statusCode}).",
      );
    }
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['message', 'detail', 'error']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } catch (_) {
      // ignore decode errors
    }
    return null;
  }
}
