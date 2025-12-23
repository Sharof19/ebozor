import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  const AppPreferences._();

  static const String _biometricKey = 'biometricEnabled';
  static const String _signedKey = 'signed';
  static const String _launchEimzoKey = 'shouldLaunchEimzo';
  static const String _cookiesAcceptedKey = 'cookiesAccepted';

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  static Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
  }

  static Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_signedKey) ?? false;
  }

  static Future<bool> hasAcceptedCookies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cookiesAcceptedKey) ?? false;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricKey);
    await prefs.remove(_signedKey);
    await prefs.remove(_launchEimzoKey);
    await prefs.remove(_cookiesAcceptedKey);
  }

  static Future<void> setSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedKey, value);
  }

  static Future<bool> shouldLaunchEimzo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_launchEimzoKey) ?? true;
  }

  static Future<void> setShouldLaunchEimzo(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_launchEimzoKey, value);
  }

  static Future<void> setCookiesAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cookiesAcceptedKey, value);
  }
}
