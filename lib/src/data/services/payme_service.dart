import 'dart:async';
import 'dart:convert';

import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PaymeService {
  PaymeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _initUri = Uri.parse(
    'https://api-edo.bek-baraka.uz/api/v1/payments/online/init/',
  );

  Future<PaymeInitResponse> initPayment({
    required int planId,
    required String amount,
  }) async {
    if (planId <= 0) {
      throw Exception("Reja ID noto'g'ri.");
    }
    final cleanedAmount = amount.trim();
    if (cleanedAmount.isEmpty) {
      throw Exception("To'lov summasi noto'g'ri.");
    }
    final token = await SecureStorageService.readAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token topilmadi.');
    }

    final response = await _authorizedPost(
      token: token,
      planId: planId,
      amount: cleanedAmount,
    );

    if (response.statusCode == 401) {
      await EimzoService().refreshToken();
      final refreshed = await SecureStorageService.readAccessToken();
      if (refreshed == null || refreshed.isEmpty) {
        throw Exception('Token yangilash muvaffaqiyatsiz bo\'ldi.');
      }
      final retry = await _authorizedPost(
        token: refreshed,
        planId: planId,
        amount: cleanedAmount,
      );
      if (retry.statusCode < 200 || retry.statusCode >= 300) {
        throw Exception(_extractMessage(retry.body) ??
            "To'lov so'rovi muvaffaqiyatsiz: HTTP ${retry.statusCode}");
      }
      return PaymeInitResponse.fromJson(retry.body);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractMessage(response.body) ??
          "To'lov so'rovi muvaffaqiyatsiz: HTTP ${response.statusCode}");
    }

    return PaymeInitResponse.fromJson(response.body);
  }

  Future<http.Response> _authorizedPost({
    required String token,
    required int planId,
    required String amount,
  }) async {
    try {
      debugPrint(
        'Payme init request => url: $_initUri, payload: {plan: $planId, amount: $amount}',
      );
      final response = await _client
          .post(
            _initUri,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Qtype': 'mobile',
              'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
            },
            body: jsonEncode({
              'plan': planId,
              'amount': amount,
            }),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint(
        'payme init response (${response.statusCode}): ${response.body}',
      );
      return response;
    } on TimeoutException {
      throw Exception("To'lov so'rovi vaqt tugadi.");
    } catch (e) {
      throw Exception("To'lov so'rovini yuborib bo'lmadi: $e");
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
    } catch (_) {}
    return null;
  }
}

class PaymeInitResponse {
  const PaymeInitResponse({
    required this.status,
    required this.message,
    required this.paymentId,
    required this.paymeUrl,
  });

  final String status;
  final String message;
  final int paymentId;
  final String paymeUrl;

  factory PaymeInitResponse.fromJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("To'lov javobi noto'g'ri formatda.");
    }
    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final paymeUrl = data['payme_url']?.toString() ?? '';
    if (paymeUrl.trim().isEmpty) {
      throw Exception("Payme havolasi topilmadi.");
    }
    return PaymeInitResponse(
      status: decoded['status']?.toString() ?? '',
      message: decoded['message']?.toString() ?? '',
      paymentId: data['payment_id'] is int
          ? data['payment_id'] as int
          : int.tryParse(data['payment_id']?.toString() ?? '') ?? 0,
      paymeUrl: paymeUrl,
    );
  }
}
