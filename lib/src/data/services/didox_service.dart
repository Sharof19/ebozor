import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ebozor/src/core/crypto_non_null/crc32.dart';
import 'package:ebozor/src/core/crypto_non_null/gost_hash.dart';
import 'package:ebozor/src/core/storage/app_preferences.dart';
import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:installed_apps/installed_apps.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class DidoxService {
  DidoxService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _signUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/sign');
  static final Uri _statusUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/status');
  static final Uri _verifyUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/verify');
  static final Uri _didoxTokenUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/didox/mobile/get/token');

  String? siteId;
  String? documentId;
  String? docHash;
  String? doc64Send;
  String? _qc;
  String? _lastPkcs;

  Future<String?> startFlow({String? stir}) async {
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

    await AppPreferences.setSignedIn(false);
    try {
      await _startSigningFlow(resolvedStir);
      await _deepLink();
      await _waitForStatus(1, allowIntermediates: const {2});
      final pkcs = await _verify();
      if (pkcs != null && pkcs.isNotEmpty) {
        await SecureStorageService.savePkcs(pkcs);
        await AppPreferences.setSignedIn(true);
      }
      return pkcs;
    } catch (e, stackTrace) {
      await AppPreferences.setSignedIn(false);
      debugPrint('Didox E-IMZO flow failed: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> _startSigningFlow(String stir) async {
    docHash = null;
    doc64Send = null;
    _qc = null;
    _lastPkcs = null;

    http.Response response;
    try {
      response = await _client.post(
        _signUri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception("Didox sign so'rovi vaqt tugadi.");
    } on SocketException {
      throw Exception(
          "Didox sign so'rovini yuborish uchun internet aloqasi talab etiladi.");
    } on http.ClientException catch (e) {
      final uriNote = e.uri != null ? ' (${e.uri})' : '';
      throw Exception("Didox sign so'rovini yuborib bo'lmadi$uriNote");
    }

    debugPrint('didox sign response: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception(
          "Didox sign so'rovi muvaffaqiyatsiz: HTTP ${response.statusCode}");
    }

    final decoded = _decodeJson(response.body);
    final status = _extractStatus(decoded);
    if (status != null && status != 1) {
      final message = _extractMessage(decoded);
      final suffix =
          (message != null && message.isNotEmpty) ? ' - $message' : '';
      throw Exception("Didox sign status xato: $status$suffix");
    }

    final data = _unwrapData(decoded);
    siteId = _extractString(data, const ['siteId', 'site_id']) ?? siteId;
    documentId = _extractString(
      data,
      const ['documentId', 'docId', 'document_id'],
    );

    if (documentId == null || documentId!.isEmpty) {
      throw Exception("Didox sign javobida documentId topilmadi.");
    }

    doc64Send = base64Encode(utf8.encode(stir));
    docHash = GostHash.hashGost(stir).toUpperCase();
  }

  Future<void> _deepLink() async {
    final currentSiteId = siteId;
    final currentDocumentId = documentId;
    final currentDocHash = docHash;
    if (currentSiteId == null ||
        currentSiteId.isEmpty ||
        currentDocumentId == null ||
        currentDocumentId.isEmpty ||
        currentDocHash == null ||
        currentDocHash.isEmpty) {
      throw Exception('Deep link uchun ma\'lumot yetarli emas');
    }

    final normalizedSiteId = currentSiteId.toLowerCase();
    String? qc = _qc?.trim();
    if (qc == null || qc.isEmpty) {
      final base = normalizedSiteId + currentDocumentId + currentDocHash;
      final crc = Crc32.calcHex(base);
      qc = base + crc;
      _qc = qc;
    }

    final deepLinkStr = qc.contains('://') ? qc : 'eimzo://sign?qc=$qc';
    debugPrint('Didox deep link: $deepLinkStr');
    final deepLink = Uri.parse(deepLinkStr);
    if (await canLaunchUrl(deepLink)) {
      await launchUrl(deepLink, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('E-IMZO ilovasini ishga tushirib bo\'lmadi.');
    }
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
        debugPrint('Didox status javobi bo\'lmadi, qayta uriniladi.');
      } else if (allowIntermediates.contains(currentStatus)) {
        debugPrint('Didox status $currentStatus, jarayon davom etmoqda...');
      } else if (currentStatus < 0) {
        throw Exception(
            "Didox status so'rovi xato holat qaytardi: $currentStatus");
      } else {
        debugPrint(
          'Didox status: $currentStatus, kutilgan: $expectedStatus',
        );
      }
      await Future.delayed(const Duration(seconds: 3));
    }
    throw TimeoutException(
        'Status $expectedStatus kutilgunga qadar Didox jarayoni tugamadi.');
  }

  Future<int?> _checkStatus() async {
    final currentDocumentId = documentId;
    if (currentDocumentId == null || currentDocumentId.isEmpty) {
      return null;
    }
    try {
      final response = await _client.post(
        _statusUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'documentId': currentDocumentId},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        debugPrint("Didox status so'rovi xato (HTTP ${response.statusCode}).");
        return null;
      }
      final decoded = _decodeJson(response.body);
      final status = _extractStatus(decoded);
      final message = _extractMessage(decoded);
      if (status == null) {
        debugPrint('Didox status javobi taniqlanmadi.');
      } else if (message != null && message.isNotEmpty && status != 1) {
        debugPrint('Didox status xabari: $message');
      }
      return status;
    } on SocketException catch (e) {
      debugPrint('Didox status socket xato: ${e.message}');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('Didox status timeout: $e');
      return null;
    } catch (e) {
      debugPrint('Didox status so\'rovi muvaffaqiyatsiz: $e');
      return null;
    }
  }

  Future<String?> _verify() async {
    final currentDocumentId = documentId;
    final currentDoc = doc64Send ?? '';
    if (currentDocumentId == null || currentDocumentId.isEmpty) {
      throw Exception('Document ID mavjud emas.');
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

    debugPrint('didox verify response (${response.statusCode}): '
        '${response.body}');

    if (response.statusCode != 200) {
      throw Exception("Didox verify so'rovi muvaffaqiyatsiz: "
          'HTTP ${response.statusCode}');
    }

    try {
      final decoded = _decodeJson(response.body);
      final status = _extractStatus(decoded);
      if (status != null && status != 1) {
        final message = _extractMessage(decoded);
        final suffix =
            (message != null && message.isNotEmpty) ? ' - $message' : '';
        throw Exception("Didox verify status xato: $status$suffix");
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
        throw Exception("Didox verify javobida PKCS bo'sh qaytdi.");
      }

      _lastPkcs = pkcs7Attached;

      final certificateInfo = _extractCertificateInfo(decoded);
      if (certificateInfo.isNotEmpty) {
        await SecureStorageService.saveCertificateInfo(certificateInfo);
        final stir = certificateInfo['stir'];
        if (stir != null && stir.isNotEmpty) {
          debugPrint('korxona STIR: $stir');
        }
      }

      await _requestDidoxToken(pkcs7Attached);

      if (Platform.isAndroid) {
        final statusPermission = await Permission.storage.request();
        if (statusPermission.isGranted) {
          const filePath = '/storage/emulated/0/Download/pkcs_document.txt';
          await File(filePath).writeAsString(pkcs7Attached);
          debugPrint('Didox PKCS saved to $filePath');
        }
      }

      return pkcs7Attached;
    } catch (e) {
      debugPrint('Error parsing Didox verify JSON: $e');
      rethrow;
    }
  }

  Future<void> _requestDidoxToken(String pkcs) async {
    try {
      final response = await _client
          .post(
            _didoxTokenUri,
            headers: {
              'accept': 'application/json',
              'Qtype': 'mobile',
              'Content-Type': 'application/json',
              'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
            },
            body: jsonEncode({'pkcs7_64': pkcs}),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('didox token response (${response.statusCode}): '
          '${response.body}');
    } on TimeoutException {
      debugPrint('didox token request timeout.');
    } catch (e) {
      debugPrint('didox token request failed: $e');
    }
  }

  Future<String> getCurrentPkcs() async {
    final pkcs = _lastPkcs ?? await SecureStorageService.readPkcs();
    if (pkcs == null || pkcs.isEmpty) {
      throw Exception("PKCS7 ma'lumot topilmadi");
    }
    return pkcs;
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

  dynamic _decodeJson(String source) {
    try {
      return jsonDecode(source);
    } catch (e) {
      throw Exception('JSON parse xatosi: $e');
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
    throw Exception("Javob formati noto'g'ri (data topilmadi).");
  }

  int? _extractStatus(dynamic source) {
    if (source is Map<String, dynamic>) {
      final status = source['status'];
      final parsed = _parseStatus(status);
      if (parsed != null) return parsed;
      final data = source['data'];
      if (data is Map<String, dynamic>) {
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
}
