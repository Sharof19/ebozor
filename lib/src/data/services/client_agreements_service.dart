import 'dart:async';
import 'dart:convert';

import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ClientAgreementsService {
  ClientAgreementsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _agreementsUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/client-agreements/');

  Future<List<ClientAgreement>> fetchAgreements() async {
    final token = await SecureStorageService.readAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token topilmadi.');
    }

    final response = await _authorizedGet(token);

    if (response.statusCode == 401) {
      debugPrint(
          'client agreements access token expired, refresh token urinish');
      await EimzoService().refreshToken();
      final refreshedToken = await SecureStorageService.readAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw Exception('Token yangilash muvaffaqiyatsiz bo\'ldi.');
      }
      final retryResponse = await _authorizedGet(refreshedToken);
      if (retryResponse.statusCode != 200) {
        throw Exception(
          'Shartnomalar so\'rovi muvaffaqiyatsiz: HTTP ${retryResponse.statusCode}',
        );
      }
      return _parseResponse(retryResponse.body);
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Shartnomalar so\'rovi muvaffaqiyatsiz: HTTP ${response.statusCode}',
      );
    }

    return _parseResponse(response.body);
  }

  Future<http.Response> _authorizedGet(String token) async {
    try {
      final response = await _client.get(
        _agreementsUri,
        headers: {
          'Authorization': 'Bearer $token',
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Qtype': 'mobile',
          'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
        },
      ).timeout(const Duration(seconds: 30));
      debugPrint('client agreements response '
          '(${response.statusCode}): ${response.body}');
      return response;
    } on TimeoutException {
      throw Exception('Shartnomalar so\'rovi vaqt tugadi.');
    } catch (e) {
      throw Exception('Shartnomalar so\'rovini yuborib bo\'lmadi: $e');
    }
  }

  List<ClientAgreement> _parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Shartnomalar javobi noto\'g\'ri formatda.');
    }
    final data = decoded['data'];
    if (data is! List) {
      return const [];
    }
    return data
        .map((item) => ClientAgreement.fromJson(item))
        .whereType<ClientAgreement>()
        .toList();
  }
}

class ClientAgreement {
  const ClientAgreement({
    required this.id,
    required this.number,
    required this.client,
    required this.contractTypeName,
    required this.startDate,
    required this.endDate,
    required this.statusName,
    required this.isActive,
    required this.signatories,
    this.readyContractUrl,
    this.readyContractName,
    this.readyContractHtml,
  });

  final int id;
  final String number;
  final String client;
  final String contractTypeName;
  final String startDate;
  final String endDate;
  final String statusName;
  final bool isActive;
  final List<AgreementSignatory> signatories;
  final String? readyContractUrl;
  final String? readyContractName;
  final String? readyContractHtml;

  factory ClientAgreement.fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return const ClientAgreement(
        id: 0,
        number: '',
        client: '',
        contractTypeName: '',
        startDate: '',
        endDate: '',
        statusName: '',
        isActive: false,
        signatories: [],
      );
    }
    final signatories = (source['signatories'] as List?)
            ?.map((item) => AgreementSignatory.fromJson(item))
            .whereType<AgreementSignatory>()
            .toList() ??
        const [];

    final ready = source['ready_contract'];
    String? readyUrl;
    String? readyName;
    String? readyHtml;
    if (ready is Map<String, dynamic>) {
      readyUrl = ready['file_url']?.toString();
      readyName = ready['file_name']?.toString();
      final content = ready['file_content'] ?? ready['html'];
      readyHtml = _extractHtml(content);
      if (readyHtml == null && readyUrl == null) {
        readyUrl = ready['file_download_url']?.toString();
      }
    } else if (ready is String && ready.isNotEmpty) {
      readyHtml = _extractHtml(ready);
      if (readyHtml == null) {
        readyUrl = ready;
      }
    }

    return ClientAgreement(
      id: source['id'] is int ? source['id'] as int : 0,
      number: source['number']?.toString() ?? '',
      client: source['client']?.toString() ?? '',
      contractTypeName: source['contract_type_name']?.toString() ?? '',
      startDate: source['start_date']?.toString() ?? '',
      endDate: source['end_date']?.toString() ?? '',
      statusName: source['status_name']?.toString() ?? '',
      isActive: source['is_active'] == true,
      signatories: signatories,
      readyContractUrl: readyUrl,
      readyContractName: readyName,
      readyContractHtml: readyHtml,
    );
  }
}

String? _extractHtml(dynamic source) {
  if (source is! String) return null;
  final content = source.trim();
  if (content.isEmpty) return null;
  if (content.startsWith('<')) {
    return content;
  }
  // Try to decode base64-encoded HTML.
  try {
    final decodedBytes = base64.decode(content);
    final decodedText = utf8.decode(decodedBytes);
    if (decodedText.trimLeft().startsWith('<')) {
      return decodedText;
    }
  } catch (_) {
    // Ignore decoding errors; fall through to null.
  }
  return null;
}

class AgreementSignatory {
  const AgreementSignatory({
    required this.name,
    required this.role,
    required this.status,
    this.signingOrder,
    this.signedAt,
    this.isSigned = false,
  });

  final String name;
  final String role;
  final String status;
  final int? signingOrder;
  final String? signedAt;
  final bool isSigned;

  factory AgreementSignatory.fromJson(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return const AgreementSignatory(
        name: '',
        role: '',
        status: '',
      );
    }
    return AgreementSignatory(
      name: source['signatory_name']?.toString() ?? '',
      role: source['role']?.toString() ?? '',
      status: source['status']?.toString() ?? '',
      signingOrder: source['signing_order'] is int
          ? source['signing_order'] as int
          : int.tryParse(source['signing_order']?.toString() ?? ''),
      signedAt: source['signed_at']?.toString(),
      isSigned: source['is_signed'] == true,
    );
  }
}
