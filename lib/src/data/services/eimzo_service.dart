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
import 'package:url_launcher/url_launcher.dart';

class EimzoService {
  EimzoService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _signUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/auth');
  static final Uri _statusUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/status');
  static final Uri _verifyUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/eimzo/mobile/verify');
  static final Uri _tokenUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/token/get/');
  static final Uri _refreshUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/token/refresh/');
  static final Uri _logoutUri =
      Uri.parse('https://api-edo.bek-baraka.uz/api/v1/logout/');

  static const String _fallbackChallenge = '3C097CA6';

  final http.Client _client;

  String? siteId;
  String? documentId;
  String? docHash;
  String? doc64Send;
  String? challenge;
  String? _qc;
  String? _lastPkcs;
  String? subjectName;
  String? subjectSurname;
  String? subjectRole;
  String? subjectOrganization;
  String? subjectPinfl;
  String? subjectStir;

  Future<String?> startFlow() async {
    if (Platform.isAndroid) {
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
    }

    await AppPreferences.setSignedIn(false);
    try {
      await _startSigningFlow();
      await _deepLink();
      await _waitForStatus(
        1,
        allowIntermediates: const {2},
        timeout: const Duration(seconds: 30),
      );
      final pkcs = await _verify();
      if (pkcs != null && pkcs.isNotEmpty) {
        await SecureStorageService.savePkcs(pkcs);
        try {
          await _requestToken(pkcs);
        } catch (e) {
          final message =
              e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          throw EimzoTokenException(message, pkcs);
        }
        await AppPreferences.setSignedIn(true);
      }
      return pkcs;
    } catch (e, stackTrace) {
      await AppPreferences.setSignedIn(false);
      debugPrint('Eimzo flow failed: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<bool> shouldLaunchEimzo() => AppPreferences.shouldLaunchEimzo();

  Future<void> refreshToken() async {
    final refreshToken = await SecureStorageService.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception("Refresh token mavjud emas");
    }
    final accessToken = await SecureStorageService.readAccessToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
      'Qtype': 'mobile',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    } else {
      debugPrint('Refresh token request without Authorization header');
    }
    final response = await _client
        .post(
          _refreshUri,
          headers: headers,
          body: jsonEncode({'refresh': refreshToken}),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint(
      'token raw response (${response.statusCode}): ${response.body}',
    );

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception(
        "Refresh token so'rovi muvaffaqiyatsiz (HTTP ${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("Refresh javobi noto'g'ri formatda: $decoded");
    }
    await _saveTokenResponse(decoded);
  }

  Future<void> logout() async {
    final accessToken = await SecureStorageService.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception("Access token mavjud emas");
    }
    final refreshToken = await SecureStorageService.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception("Refresh token mavjud emas");
    }

    final response = await _client
        .post(
          _logoutUri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh': refreshToken}),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint(
      'logout response (${response.statusCode}): ${response.body}',
    );

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception(
        "Chiqish so'rovi rad etildi (HTTP ${response.statusCode}).",
      );
    }
  }

  Future<Map<String, String>?> loadCertificateInfo() async {
    final stored = await SecureStorageService.readCertificateInfo();
    if (stored != null && stored.isNotEmpty) {
      subjectName = stored['name'];
      subjectSurname = stored['surname'];
      subjectRole = stored['role'];
      subjectOrganization = stored['organization'];
      subjectPinfl = stored['pinfl'];
      subjectStir = stored['stir'];
    }
    return stored;
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
        'X-Real-IP': '188.113.252.134',
      },
      body: {
        'documentId': currentDocumentId,
        'document': currentDoc,
      },
    ).timeout(const Duration(seconds: 30));

    debugPrint(
      'verify raw response (${response.statusCode}): ${response.body}',
    );

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception(
        "Verify so'rovi muvaffaqiyatsiz (HTTP ${response.statusCode}).",
      );
    }

    try {
      final decoded = jsonDecode(response.body);
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
        final status = _extractStatus(decoded);
        if (status != null && status != 1) {
          final message = _extractMessage(data) ?? _extractMessage(decoded);
          final normalized = message?.trim() ?? '';
          if (status == -9 || normalized.contains('Signing time is out of valid range')) {
            throw Exception(
              "Imzo vaqti noto'g'ri. Telefon vaqtini avtomatik sozlang.",
            );
          }
          final suffix =
              (normalized.isNotEmpty) ? ' - $normalized' : '';
          throw Exception(
            "Verify so'rovi muvaffaqiyatsiz: status $status$suffix",
          );
        }
        throw Exception("PKCS7 ma'lumot bo'sh qaytdi");
      }

      _lastPkcs = pkcs7Attached;

      final certificateInfo = _extractCertificateInfo(decoded);
      if (certificateInfo.isNotEmpty) {
        subjectName = certificateInfo['name'];
        subjectSurname = certificateInfo['surname'];
        subjectRole = certificateInfo['role'];
        subjectOrganization = certificateInfo['organization'];
        subjectPinfl = certificateInfo['pinfl'];
        subjectStir = certificateInfo['stir'];
        await SecureStorageService.saveCertificateInfo(certificateInfo);
      }

      return pkcs7Attached;
    } catch (e) {
      debugPrint('Error parsing verify JSON: $e');
      rethrow;
    }
  }

  String? get currentPkcs => _lastPkcs;

  Future<String> getCurrentPkcs() async {
    final pkcs = _lastPkcs ?? await SecureStorageService.readPkcs();
    if (pkcs == null || pkcs.isEmpty) {
      throw Exception("PKCS7 ma'lumot topilmadi");
    }
    return pkcs;
  }

  Future<void> _startSigningFlow() async {
    challenge = null;
    docHash = null;
    doc64Send = null;
    _qc = null;
    _lastPkcs = null;
    subjectName = null;
    subjectSurname = null;
    subjectRole = null;
    subjectOrganization = null;
    subjectPinfl = null;
    subjectStir = null;

    await SecureStorageService.clearCertificateInfo();

    http.Response response;
    try {
      response = await _client.post(
        _signUri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception(
          "E-IMZO serveridan javob kelmadi. Iltimos, qayta urinib ko'ring.");
    } on SocketException catch (e) {
      throw Exception(
        "E-IMZO serveriga ulanib bo'lmadi: ${e.message}. Internet ulanishingizni tekshiring.",
      );
    } on http.ClientException catch (e) {
      final uriNote = e.uri != null ? ' (${e.uri})' : '';
      throw Exception("E-IMZO so'rovi amalga oshmadi: ${e.message}$uriNote");
    }

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception('Failed to start sign flow: ${response.statusCode}.');
    }

    debugPrint('sign response: ${response.body}');
    final decoded = jsonDecode(response.body);
    final status = _extractStatus(decoded);
    if (status != null && status != 1) {
      final message = _extractMessage(decoded);
      final suffix =
          (message != null && message.isNotEmpty) ? ', message: $message' : '';
      throw Exception("Sign so'rovi muvaffaqiyatsiz (status: $status$suffix)");
    }
    final data = _unwrapData(decoded);
    siteId = _extractString(data, const ['siteId', 'site_id']) ?? siteId;
    documentId = _extractString(
      data,
      const ['documentId', 'document_id', 'docId', 'doc_id'],
    );

    final docCandidate = _extractString(
      data,
      const ['document', 'documentBase64', 'doc', 'doc64'],
    );
    if (docCandidate != null && docCandidate.trim().isNotEmpty) {
      doc64Send = docCandidate.trim();
    }

    final docHashCandidate = _extractString(
      data,
      const ['docHash', 'documentHash', 'hash'],
    );
    if (docHashCandidate != null && docHashCandidate.trim().isNotEmpty) {
      docHash = docHashCandidate.trim().toUpperCase();
    }

    final challengeCandidate = _extractString(
      data,
      const ['challenge', 'challange'],
    );
    if (challengeCandidate != null && challengeCandidate.trim().isNotEmpty) {
      challenge = challengeCandidate.trim();
    }

    challenge ??= _fallbackChallenge;
    if (challenge != null && challenge!.isNotEmpty) {
      doc64Send ??= base64Encode(utf8.encode(challenge!));
      docHash ??= GostHash.hashGost(challenge!).toUpperCase();
    }

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
    final currentSiteId = siteId;
    final currentDocumentId = documentId;
    final currentDocHash = docHash;
    if (currentSiteId == null ||
        currentDocumentId == null ||
        currentDocumentId.isEmpty ||
        currentDocHash == null ||
        currentDocHash.isEmpty) {
      throw Exception('Missing data for deep link');
    }

    await _ensureDocumentPayload();

    final normalizedSiteId = currentSiteId.toLowerCase();
    String? qc = _qc?.trim();
    if (qc == null || qc.isEmpty) {
      final base = normalizedSiteId + currentDocumentId + currentDocHash;
      final crc = Crc32.calcHex(base);
      qc = base + crc;
      _qc = qc;
    } else {
      docHash = docHash?.toUpperCase();
    }

    final deepLinkStr = qc.contains('://') ? qc : 'eimzo://sign?qc=$qc';
    debugPrint('Launching deep link: $deepLinkStr');
    final deepLink = Uri.parse(deepLinkStr);
    if (await canLaunchUrl(deepLink)) {
      await launchUrl(deepLink, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Cannot launch Eimzo deep link');
    }
  }

  Future<void> _ensureDocumentPayload() async {
    if (doc64Send != null &&
        doc64Send!.isNotEmpty &&
        docHash != null &&
        docHash!.isNotEmpty) {
      docHash = docHash!.toUpperCase();
      return;
    }

    if (challenge != null && challenge!.isNotEmpty) {
      doc64Send ??= base64Encode(utf8.encode(challenge!));
      docHash ??= GostHash.hashGost(challenge!).toUpperCase();
    }

    if (doc64Send == null ||
        doc64Send!.isEmpty ||
        docHash == null ||
        docHash!.isEmpty) {
      throw Exception("Challenge ma'lumotlari topilmadi");
    }

    docHash = docHash!.toUpperCase();
  }

  Future<void> _waitForStatus(
    int expectedStatus, {
    Set<int> allowIntermediates = const {},
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final currentStatus = await _checkStatus();
      if (currentStatus == expectedStatus) return;
      if (currentStatus == null) {
        debugPrint('Status tekshiruvi javob qaytarmadi, qayta uriniladi.');
      } else if (allowIntermediates.contains(currentStatus)) {
        debugPrint('Status $currentStatus qaytdi, natija kutilmoqda.');
      } else if (currentStatus < 0) {
        throw Exception("Status so'rovi xato holat qaytardi: $currentStatus");
      } else {
        debugPrint(
          'Kutilmagan status: $currentStatus, kutilgani: $expectedStatus',
        );
      }
      await Future.delayed(const Duration(seconds: 3));
    }
    throw TimeoutException('Timeout waiting for status $expectedStatus');
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
      if (response.statusCode != 200 && response.statusCode != 205) {
        debugPrint("Status so'rovi xato (HTTP ${response.statusCode}).");
        return null;
      }
      final decoded = jsonDecode(response.body);
      final status = _extractStatus(decoded);
      final message = _extractMessage(decoded);
      if (status == null) {
        debugPrint('Status javobi taniqlanmadi.');
      } else if (message != null && message.isNotEmpty && status != 1) {
        debugPrint('Status xabari: $message');
      }
      return status;
    } on SocketException catch (e) {
      debugPrint('Status request socket error: ${e.message}');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('Status request timeout: $e');
      return null;
    } catch (e) {
      debugPrint('Status request failed: $e');
      return null;
    }
  }

  Future<void> _requestToken(String pkcs) async {
    final previewLength = pkcs.length > 120 ? 120 : pkcs.length;
    debugPrint(
      'token request pkcs7 preview: ${pkcs.substring(0, previewLength)}',
    );

    final response = await _client
        .post(
          _tokenUri,
          headers: {
            'Content-Type': 'application/json',
            'X-CSRFTOKEN': '1dOGlqAssmP1pK1OU8PwJyh7gBbBygJw',
            'Qtype': 'mobile',
          },
          body: jsonEncode({'pkcs7_64': pkcs}),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint(
      'token raw response (${response.statusCode}): ${response.body}',
    );

    if (response.statusCode != 200 && response.statusCode != 205) {
      throw Exception(
        'Token olishda xato (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    debugPrint('token response: $decoded');
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Token javobi noto\'g\'ri formatda: ');
    }

    await _saveTokenResponse(decoded);
  }

  Future<void> _saveTokenResponse(Map<String, dynamic> data) async {
    final tokenData = data['data'];
    final Map<String, dynamic> effectiveData =
        tokenData is Map<String, dynamic> ? tokenData : data;

    final accessToken = _extractString(effectiveData, const [
      'token',
      'accessToken',
      'access_token',
      'access',
    ]);
    final refreshToken = _extractString(
        effectiveData, const ['refreshToken', 'refresh_token', 'refresh']);

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token topilmadi');
    }

    await SecureStorageService.saveAccessToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await SecureStorageService.saveRefreshToken(refreshToken);
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
    throw Exception("Signing javobi noto'g'ri formatda: ");
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
}

class EimzoTokenException implements Exception {
  EimzoTokenException(this.message, this.pkcs);

  final String message;
  final String pkcs;

  @override
  String toString() => message;
}
