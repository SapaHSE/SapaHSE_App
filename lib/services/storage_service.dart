import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';
  static const _keyExpiry = 'auth_expiry';
  static const _keyRememberMe = 'auth_remember';
  static const _keyBiometricEnabled = 'biometric_enabled';

  static SharedPreferences? _prefs;
  static const _secureStorage = FlutterSecureStorage();
  
  // ── In-Memory Cache ───────────────────────────────────────────────────────
  static String? _cachedToken;
  static Map<String, dynamic>? _cachedUser;
  static bool _hasLoadedUser = false;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Token ─────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token, {required bool rememberMe}) async {
    final prefs = await _getPrefs();
    _cachedToken = token; // Update cache

    await prefs.setString(_keyToken, token);
    await prefs.setBool(_keyRememberMe, rememberMe);

    if (rememberMe) {
      await prefs.remove(_keyExpiry);
    } else {
      final expiry = DateTime.now().add(const Duration(minutes: 15)).toIso8601String();
      await prefs.setString(_keyExpiry, expiry);
    }
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;

    final prefs = await _getPrefs();
    final token = prefs.getString(_keyToken);
    if (token == null) return null;

    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (rememberMe) {
      _cachedToken = token;
      return token;
    }

    final expiry = prefs.getString(_keyExpiry);
    if (expiry == null) return null;

    final expiryDate = DateTime.parse(expiry);
    if (DateTime.now().isAfter(expiryDate)) {
      await clear();
      return null;
    }

    _cachedToken = token;
    return token;
  }

  static Future<void> removeToken() async {
    final prefs = await _getPrefs();
    _cachedToken = null;
    await prefs.remove(_keyToken);
    await prefs.remove(_keyExpiry);
    await prefs.remove(_keyRememberMe);
  }

  // ── User ──────────────────────────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await _getPrefs();
    _cachedUser = user;
    _hasLoadedUser = true;
    await prefs.setString(_keyUser, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    if (_hasLoadedUser) return _cachedUser;

    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyUser);
    if (raw == null) {
      _hasLoadedUser = true;
      return null;
    }

    try {
      _cachedUser = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _cachedUser = null;
    }
    _hasLoadedUser = true;
    return _cachedUser;
  }

  static Future<void> removeUser() async {
    final prefs = await _getPrefs();
    _cachedUser = null;
    _hasLoadedUser = false;
    await prefs.remove(_keyUser);
  }

  // ── Clear semua ───────────────────────────────────────────────────────────
  static Future<void> clear() async {
    final prefs = await _getPrefs();
    _cachedToken = null;
    _cachedUser = null;
    _hasLoadedUser = false;

    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyExpiry);
    await prefs.remove(_keyRememberMe);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  static Future<Duration?> getRemainingSession() async {
    final prefs = await _getPrefs();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (rememberMe) return null;

    final expiry = prefs.getString(_keyExpiry);
    if (expiry == null) return null;

    final expiryDate = DateTime.parse(expiry);
    final remaining = expiryDate.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  // ── Biometric Login ───────────────────────────────────────────────────────
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    if (!enabled) {
      await clearBiometricCredentials();
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> saveBiometricCredentials(String loginId, String password) async {
    await _secureStorage.write(key: 'biometric_login_id', value: loginId);
    await _secureStorage.write(key: 'biometric_password', value: password);
  }

  static Future<Map<String, String>?> getBiometricCredentials() async {
    final loginId = await _secureStorage.read(key: 'biometric_login_id');
    final password = await _secureStorage.read(key: 'biometric_password');
    if (loginId != null && password != null) {
      return {'loginId': loginId, 'password': password};
    }
    return null;
  }

  static Future<void> clearBiometricCredentials() async {
    await _secureStorage.delete(key: 'biometric_login_id');
    await _secureStorage.delete(key: 'biometric_password');
  }
}
