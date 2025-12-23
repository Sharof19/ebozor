import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  const SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _jshshrKey = 'jshshr';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _pkcsKey = 'pkcs7_64';
  static const String _certificateInfoKey = 'certificate_info';
  static const String _myKeyKey = 'my_key';

  static Future<void> saveJshshr(String value) =>
      _storage.write(key: _jshshrKey, value: value);

  static Future<String?> readJshshr() => _storage.read(key: _jshshrKey);

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  static Future<String?> readAccessToken() =>
      _storage.read(key: _accessTokenKey);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  static Future<String?> readRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> savePkcs(String pkcs) =>
      _storage.write(key: _pkcsKey, value: pkcs);

  static Future<String?> readPkcs() => _storage.read(key: _pkcsKey);

  static Future<void> clearPkcs() => _storage.delete(key: _pkcsKey);

  static Future<void> saveMyKey(String key) =>
      _storage.write(key: _myKeyKey, value: key);

  static Future<String?> readMyKey() => _storage.read(key: _myKeyKey);

  static Future<void> clearMyKey() => _storage.delete(key: _myKeyKey);

  static Future<void> saveCertificateInfo(Map<String, String> info) =>
      _storage.write(key: _certificateInfoKey, value: jsonEncode(info));

  static Future<Map<String, String>?> readCertificateInfo() async {
    final raw = await _storage.read(key: _certificateInfoKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final result = <String, String>{};
    decoded.forEach((key, value) {
      if (key is String && value != null) {
        result[key] = value.toString();
      }
    });
    return result;
  }

  static Future<void> clearCertificateInfo() =>
      _storage.delete(key: _certificateInfoKey);

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  static Future<void> clearAuthData() async {
    await _storage.deleteAll();
  }
}
