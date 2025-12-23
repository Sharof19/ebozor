import 'dart:async';
import 'dart:convert';

import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PaymentPlanService {
  PaymentPlanService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static List<Uri> _planUris(int agreementId) => [
        Uri.parse(
          'https://api-edo.bek-baraka.uz/api/v1/client/agreements/$agreementId/plan/',
        ),
      ];

  Future<ClientPaymentPlan> fetchPlan({required int agreementId}) async {
    if (agreementId <= 0) {
      throw Exception('Agreement ID noto\'g\'ri.');
    }
    final token = await SecureStorageService.readAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token topilmadi.');
    }

    final response = await _authorizedGet(token, agreementId);

    if (response.statusCode == 401) {
      await EimzoService().refreshToken();
      final refreshedToken = await SecureStorageService.readAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw Exception('Token yangilash muvaffaqiyatsiz bo\'ldi.');
      }
      final retryResponse = await _authorizedGet(refreshedToken, agreementId);
      if (retryResponse.statusCode != 200) {
        throw Exception(
          "To'lov rejasi so'rovi muvaffaqiyatsiz: HTTP ${retryResponse.statusCode}",
        );
      }
      return _parseResponse(retryResponse.body);
    }

    if (response.statusCode != 200) {
      throw Exception(
        "To'lov rejasi so'rovi muvaffaqiyatsiz: HTTP ${response.statusCode}",
      );
    }

    return _parseResponse(response.body);
  }

  Future<http.Response> _authorizedGet(String token, int agreementId) async {
    http.Response? lastResponse;
    Uri? lastUri;
    try {
      for (final uri in _planUris(agreementId)) {
        final response = await _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Qtype': 'mobile',
            'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
          },
        ).timeout(const Duration(seconds: 30));
        debugPrint(
          'payment plan response (${response.statusCode}) for $uri: ${response.body}',
        );
        lastResponse = response;
        lastUri = uri;
        if (response.statusCode == 200) {
          return response;
        }
      }
    } on TimeoutException {
      throw Exception("To'lov rejasi so'rovi vaqt tugadi.");
    } catch (e) {
      throw Exception("To'lov rejasi so'rovini yuborib bo'lmadi: $e");
    }

    if (lastResponse != null) {
      final message = _extractMessage(lastResponse.body) ??
          "To'lov rejasi so'rovi muvaffaqiyatsiz: HTTP ${lastResponse.statusCode} (${lastUri ?? 'nomaʼlum URL'})";
      throw Exception(message);
    }
    throw Exception("To'lov rejasi so'rovi amalga oshmadi.");
  }

  ClientPaymentPlan _parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("To'lov rejasi javobi noto'g'ri formatda.");
    }
    final data = decoded['data'] ?? decoded;
    return ClientPaymentPlan.fromJson(data);
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
      // ignore
    }
    return null;
  }
}

class ClientPaymentPlan {
  const ClientPaymentPlan({
    required this.id,
    required this.totalAmount,
    required this.monthsCount,
    required this.isFullyPaid,
    required this.schedules,
  });

  final int id;
  final String totalAmount;
  final int monthsCount;
  final bool isFullyPaid;
  final List<ClientSchedule> schedules;

  factory ClientPaymentPlan.fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return const ClientPaymentPlan(
        id: 0,
        totalAmount: '',
        monthsCount: 0,
        isFullyPaid: false,
        schedules: [],
      );
    }
    final scheduleList = (source['schedules'] as List?)
            ?.map((item) => ClientSchedule.fromJson(item))
            .whereType<ClientSchedule>()
            .toList() ??
        const [];

    return ClientPaymentPlan(
      id: source['id'] is int ? source['id'] as int : 0,
      totalAmount: source['total_amount']?.toString() ?? '',
      monthsCount: source['months_count'] is int
          ? source['months_count'] as int
          : int.tryParse(source['months_count']?.toString() ?? '') ?? 0,
      isFullyPaid: source['is_fully_paid'] == true,
      schedules: scheduleList,
    );
  }
}

class ClientSchedule {
  const ClientSchedule({
    required this.id,
    required this.order,
    required this.dueDate,
    required this.amount,
    this.paidAmount,
    this.status,
    this.progress,
    this.isOverdue = false,
  });

  final int id;
  final int order;
  final String dueDate;
  final String amount;
  final String? paidAmount;
  final String? status;
  final num? progress;
  final bool isOverdue;

  factory ClientSchedule.fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return const ClientSchedule(
        id: 0,
        order: 0,
        dueDate: '',
        amount: '',
        isOverdue: false,
      );
    }

    return ClientSchedule(
      id: source['id'] is int ? source['id'] as int : 0,
      order: source['order'] is int
          ? source['order'] as int
          : int.tryParse(source['order']?.toString() ?? '') ?? 0,
      dueDate: source['due_date']?.toString() ?? '',
      amount: source['amount']?.toString() ?? '',
      paidAmount: source['paid_amount']?.toString(),
      status: source['status']?.toString(),
      progress: source['progress'] is num
          ? source['progress'] as num
          : num.tryParse(source['progress']?.toString() ?? ''),
      isOverdue: source['is_overdue'] == true,
    );
  }
}
