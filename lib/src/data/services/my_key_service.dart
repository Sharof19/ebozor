import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ebozor/src/core/crypto_non_null/crc32.dart';
import 'package:ebozor/src/core/crypto_non_null/gost_hash.dart';
import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

class MyKeyService {
  MyKeyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _signUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/sign');
  static final Uri _statusUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/status');
  static final Uri _verifyUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/verify');

  String? _siteId;
  String? _documentId;
  String? _docHash;
  String? _doc64Send;
  String? _qc;
  String? _lastKey;

  Future<String?> createMyKey({String? stir}) async {
    final resolvedStir = await _resolveStir(stir);

    final isInstalled =
        await InstalledApps.isAppInstalled('uz.yt.idcard.eimzo') ?? false;
    if (!isInstalled) {
      await launchUrl(
        Uri.parse(
            'https://play.google.com/store/apps/details?id=uz.yt.idcard.eimzo'),
        mode: LaunchMode.externalApplication,
      );
      return null;
    }

    try {
      await _startSigningFlow(resolvedStir);
      await _deepLink();
      await _waitForStatus(1, allowIntermediates: const {2});
      final pkcs = await _verify();
      if (pkcs != null && pkcs.isNotEmpty) {
        await SecureStorageService.saveMyKey(pkcs);
      }
      return pkcs;
    } catch (e, stackTrace) {
      debugPrint('MyKey flow failed: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  String? get currentKey => _lastKey;

  Future<String> getStoredKey() async {
    final key = _lastKey ?? await SecureStorageService.readMyKey();
    if (key == null || key.isEmpty) {
      throw Exception('MyKey topilmadi');
    }
    return key;
  }

  Future<void> _startSigningFlow(String stir) async {
    _siteId = null;
    _documentId = null;
    _docHash = null;
    _doc64Send = null;
    _qc = null;
    _lastKey = null;

    http.Response response;
    try {
      response = await _client.post(
        _signUri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception(
        "MyKey sign so'rovi vaqt tugadi. Iltimos, qayta urinib ko'ring.",
      );
    } on SocketException catch (e) {
      throw Exception(
        "MyKey sign so'rovini yuborib bo'lmadi: ${e.message}. Internet ulanishingizni tekshiring.",
      );
    } on http.ClientException catch (e) {
      final uriNote = e.uri != null ? ' (${e.uri})' : '';
      throw Exception(
          "MyKey sign so'rovi amalga oshmadi: ${e.message}$uriNote");
    }

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception(
        "MyKey sign so'rovi muvaffaqiyatsiz: HTTP ${response.statusCode}",
      );
    }

    final decoded = jsonDecode(response.body);
    final status = _extractStatus(decoded);
    if (status != null && status != 1) {
      final message = _extractMessage(decoded);
      final suffix =
          (message != null && message.isNotEmpty) ? ', message: $message' : '';
      throw Exception(
        "MyKey sign so'rovi muvaffaqiyatsiz (status: $status$suffix)",
      );
    }

    final data = _unwrapData(decoded);
    _siteId = _extractString(data, const ['siteId', 'site_id']) ?? _siteId;
    _documentId = _extractString(
      data,
      const ['documentId', 'document_id', 'docId', 'doc_id'],
    );

    if (_documentId == null || _documentId!.isEmpty) {
      throw Exception("MyKey sign javobida documentId topilmadi.");
    }

    _doc64Send = base64Encode(utf8.encode(stir));
    _docHash = GostHash.hashGost(stir).toUpperCase();

    final deepLinkCandidate = _extractString(
          data,
          const ['qc', 'code', 'deepLink', 'deeplink'],
        ) ??
        (decoded is Map<String, dynamic>
            ? _extractString(
                decoded,
                const ['qc', 'code', 'deepLink', 'deeplink'],
              )
            : null);
    if (deepLinkCandidate != null) {
      final uri = Uri.tryParse(deepLinkCandidate);
      if (uri != null && uri.queryParameters.containsKey('qc')) {
        _qc = uri.queryParameters['qc'];
      } else {
        _qc = deepLinkCandidate;
      }
    }
  }

  Future<void> _deepLink() async {
    final currentSiteId = _siteId;
    final currentDocumentId = _documentId;
    final currentDocHash = _docHash;
    if (currentSiteId == null ||
        currentDocumentId == null ||
        currentDocumentId.isEmpty ||
        currentDocHash == null ||
        currentDocHash.isEmpty) {
      throw Exception('MyKey deep link uchun ma\'lumot yetarli emas');
    }

    _ensureDocumentPayload();

    final normalizedSiteId = currentSiteId.toLowerCase();
    String? qc = _qc?.trim();
    if (qc == null || qc.isEmpty) {
      final base = normalizedSiteId + currentDocumentId + currentDocHash;
      final crc = Crc32.calcHex(base);
      qc = base + crc;
      _qc = qc;
    } else {
      _docHash = _docHash?.toUpperCase();
    }

    final deepLinkStr = qc.contains('://') ? qc : 'eimzo://sign?qc=$qc';
    debugPrint('MyKey deep link: $deepLinkStr');
    final deepLink = Uri.parse(deepLinkStr);
    if (await canLaunchUrl(deepLink)) {
      await launchUrl(deepLink, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('E-IMZO ilovasini ishga tushirib bo\'lmadi.');
    }
  }

  void _ensureDocumentPayload() {
    if (_doc64Send != null &&
        _doc64Send!.isNotEmpty &&
        _docHash != null &&
        _docHash!.isNotEmpty) {
      _docHash = _docHash!.toUpperCase();
      return;
    }
    throw Exception("MyKey uchun STIR ma'lumotlari topilmadi.");
  }

  Future<void> _waitForStatus(
    int expectedStatus, {
    Set<int> allowIntermediates = const {},
  }) async {
    const timeout = Duration(minutes: 2);
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final currentStatus = await _checkStatus();
      if (currentStatus == expectedStatus) return;
      if (currentStatus == null) {
        debugPrint('MyKey status javobi bo\'lmadi, qayta uriniladi.');
      } else if (allowIntermediates.contains(currentStatus)) {
        debugPrint('MyKey status $currentStatus, jarayon davom etmoqda.');
      } else if (currentStatus < 0) {
        throw Exception(
          "MyKey status so'rovi xato holat qaytardi: $currentStatus",
        );
      } else {
        debugPrint(
          'MyKey status: $currentStatus, kutilgani: $expectedStatus',
        );
      }
      await Future.delayed(const Duration(seconds: 3));
    }
    throw TimeoutException('MyKey status $expectedStatus kutilmoqda.');
  }

  Future<int?> _checkStatus() async {
    final currentDocumentId = _documentId;
    if (currentDocumentId == null || currentDocumentId.isEmpty) {
      return null;
    }
    try {
      final response = await _client.post(
        _statusUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'documentId': currentDocumentId},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 205) {
        debugPrint("MyKey status so'rovi xato (HTTP ${response.statusCode}).");
        return null;
      }
      final decoded = jsonDecode(response.body);
      final status = _extractStatus(decoded);
      final message = _extractMessage(decoded);
      if (status == null) {
        debugPrint('MyKey status javobi taniqlanmadi.');
      } else if (message != null && message.isNotEmpty && status != 1) {
        debugPrint('MyKey status xabari: $message');
      }
      return status;
    } on SocketException catch (e) {
      debugPrint('MyKey status socket xato: ${e.message}');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('MyKey status timeout: $e');
      return null;
    } catch (e) {
      debugPrint('MyKey status so\'rovi muvaffaqiyatsiz: $e');
      return null;
    }
  }

  Future<String?> _verify() async {
    final currentDocumentId = _documentId;
    final currentDoc = _doc64Send ?? '';
    if (currentDocumentId == null || currentDocumentId.isEmpty) {
      throw Exception('MyKey verify uchun documentId mavjud emas.');
    }

    final response = await _client.post(
      _verifyUri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'documentId': currentDocumentId,
        'document': currentDoc,
      },
    ).timeout(const Duration(seconds: 30));

    debugPrint(
      'MyKey verify response (${response.statusCode}): ${response.body}',
    );

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception(
        "MyKey verify so'rovi muvaffaqiyatsiz: HTTP ${response.statusCode}",
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final status = _extractStatus(decoded);
      if (status != null && status != 1) {
        final message = _extractMessage(decoded);
        final suffix =
            (message != null && message.isNotEmpty) ? ' - $message' : '';
        throw Exception("MyKey verify status xato: $status$suffix");
      }
      final data = _unwrapData(decoded);
      final pkcs7Attached = _extractString(
            data,
            const ['pkcs7Attached', 'pkcs7_attached', 'pkcs'],
          ) ??
          (decoded is Map<String, dynamic>
              ? _extractString(
                  decoded, const ['pkcs7Attached', 'pkcs7_attached', 'pkcs'])
              : null) ??
          '';
      if (pkcs7Attached.isEmpty) {
        throw Exception("MyKey verify javobida PKCS bo'sh qaytdi.");
      }

      _lastKey = pkcs7Attached;

      final certificateInfo = _extractCertificateInfo(decoded);
      if (certificateInfo.isNotEmpty) {
        await SecureStorageService.saveCertificateInfo(certificateInfo);
      }

      return pkcs7Attached;
    } catch (e) {
      debugPrint('MyKey verify JSON xatosi: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _unwrapData(dynamic source) {
    if (source is Map<String, dynamic>) {
      final nested = source['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return source;
    }
    throw Exception("MyKey javobi noto'g'ri formatda.");
  }

  int? _extractStatus(dynamic source) {
    if (source is Map<String, dynamic>) {
      final status = source['status'];
      final parsed = _parseStatus(status);
      if (parsed != null) return parsed;
      final data = source['data'];
      if (data is Map<String, dynamic>) {
        final nested = data['status'];
        final nestedParsed = _parseStatus(nested);
        if (nestedParsed != null) {
          return nestedParsed;
        }
        return _extractStatus(data);
      }
    }
    return null;
  }

  int? _parseStatus(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _extractMessage(dynamic source) {
    if (source is Map<String, dynamic>) {
      for (final key in const ['message', 'error', 'detail', 'errorMessage']) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      final data = source['data'];
      if (data is Map<String, dynamic>) {
        final nested = _extractMessage(data);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      } else if (value is num) {
        return value.toString();
      }
    }
    return null;
  }

  Map<String, String> _extractCertificateInfo(dynamic source) {
    final info = <String, String>{};
    final name = _findValueByKey(source, 'Name');
    if (name != null && name.trim().isNotEmpty) {
      info['name'] = name.trim();
    }
    final surname = _findValueByKey(source, 'SURNAME');
    if (surname != null && surname.trim().isNotEmpty) {
      info['surname'] = surname.trim();
    }
    final role = _findValueByKey(source, 'T');
    if (role != null && role.trim().isNotEmpty) {
      info['role'] = role.trim();
    }
    final organization = _findValueByKey(source, 'O');
    if (organization != null && organization.trim().isNotEmpty) {
      info['organization'] = organization.trim();
    }
    final pinfl = _findValueByKey(source, '1.2.860.3.16.1.2');
    if (pinfl != null && pinfl.trim().isNotEmpty) {
      info['pinfl'] = pinfl.trim();
    }
    final stir = _findValueByKey(source, '1.2.860.3.16.1.1');
    if (stir != null && stir.trim().isNotEmpty) {
      info['stir'] = stir.trim();
    }
    final serialNumber = _findValueByKey(source, 'serialNumber');
    if (serialNumber != null && serialNumber.trim().isNotEmpty) {
      info['serialNumber'] = serialNumber.trim();
    }
    final uid = _findValueByKey(source, 'UID');
    if (uid != null && uid.trim().isNotEmpty) {
      info['uid'] = uid.trim();
    }
    final locality = _findValueByKey(source, 'L');
    if (locality != null && locality.trim().isNotEmpty) {
      info['locality'] = locality.trim();
    }
    final region = _findValueByKey(source, 'ST');
    if (region != null && region.trim().isNotEmpty) {
      info['region'] = region.trim();
    }
    final country = _findValueByKey(source, 'C');
    if (country != null && country.trim().isNotEmpty) {
      info['country'] = country.trim();
    }
    final x500 = _findValueByKey(source, 'X500Name');
    if (x500 != null && x500.trim().isNotEmpty) {
      info['x500'] = x500.trim();
    }
    return info;
  }

  String? _findValueByKey(dynamic source, String targetKey) {
    if (source is Map) {
      for (final entry in source.entries) {
        if (entry.key == targetKey) {
          final value = entry.value;
          if (value is String) {
            return value;
          }
          if (value is num || value is bool) {
            return value.toString();
          }
        }
        final nested = _findValueByKey(entry.value, targetKey);
        if (nested != null && nested.trim().isNotEmpty) {
          return nested;
        }
      }
    } else if (source is Iterable) {
      for (final item in source) {
        final nested = _findValueByKey(item, targetKey);
        if (nested != null && nested.trim().isNotEmpty) {
          return nested;
        }
      }
    }
    return null;
  }

  Future<String> _resolveStir(String? stir) async {
    final candidate = stir?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }

    final storedInfo = await SecureStorageService.readCertificateInfo();
    final storedStir = storedInfo?['stir']?.trim();
    if (storedStir != null && storedStir.isNotEmpty) {
      return storedStir;
    }
    final storedPinfl = storedInfo?['pinfl']?.trim();
    if (storedPinfl != null && storedPinfl.isNotEmpty) {
      return storedPinfl;
    }

    throw Exception(
      'STIR topilmadi. Iltimos, E-IMZO orqali identifikatsiyadan o\'ting yoki STIR kiriting.',
    );
  }
}
