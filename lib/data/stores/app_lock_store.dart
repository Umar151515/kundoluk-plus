import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockStore extends ChangeNotifier {
  final SharedPreferences prefs;
  AppLockStore(this.prefs);

  static const _kEnabled = 'app_lock_enabled';
  static const _kHash = 'app_lock_hash';
  static const _kTimeoutSec = 'app_lock_timeout_sec';
  static const _kBiometricEnabled = 'app_lock_biometric_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAuthInProgress = false;

  bool enabled = false;
  String? _hash;
  int timeoutSec = 60;
  bool biometricEnabled = false;

  bool get hasPasscode => _hash != null && _hash!.isNotEmpty;

  Future<void> load() async {
    enabled = prefs.getBool(_kEnabled) ?? false;
    _hash = prefs.getString(_kHash);
    timeoutSec = prefs.getInt(_kTimeoutSec) ?? 60;
    biometricEnabled = prefs.getBool(_kBiometricEnabled) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    await prefs.setBool(_kEnabled, v);
    notifyListeners();
  }

  Future<void> setTimeoutSec(int sec) async {
    timeoutSec = sec.clamp(0, 24 * 3600);
    await prefs.setInt(_kTimeoutSec, timeoutSec);
    notifyListeners();
  }

  String _weakHash(String input) {
    int h = 0x811c9dc5;
    for (final c in input.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Future<void> setPasscode(String passcode) async {
    final normalized = passcode.trim();
    _hash = _weakHash(normalized);
    await prefs.setString(_kHash, _hash!);
    if (!enabled) {
      enabled = true;
      await prefs.setBool(_kEnabled, true);
    }
    notifyListeners();
  }

  Future<void> clearPasscode() async {
    _hash = null;
    enabled = false;
    biometricEnabled = false;
    await prefs.remove(_kHash);
    await prefs.setBool(_kEnabled, false);
    await prefs.setBool(_kBiometricEnabled, false);
    notifyListeners();
  }

  bool verify(String passcode) {
    final h = _hash;
    if (h == null || h.isEmpty) return false;
    return _weakHash(passcode.trim()) == h;
  }

  bool get biometricAuthInProgress => _biometricAuthInProgress;

  Future<void> setBiometricEnabled(bool v) async {
    biometricEnabled = v;
    await prefs.setBool(_kBiometricEnabled, v);
    notifyListeners();
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  Future<bool> canUseBiometrics() async {
    if (!_isSupportedPlatform) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported && !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      if (available.isNotEmpty) return true;
      return defaultTargetPlatform == TargetPlatform.windows && supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isSupportedPlatform) return false;
    try {
      if (!await canUseBiometrics()) return false;
      _biometricAuthInProgress = true;
      final biometricOnly = false; // allow device-credential fallback on Android
      return await _localAuth.authenticate(
        localizedReason: 'Подтвердите вход в приложение',
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    } finally {
      _biometricAuthInProgress = false;
    }
  }
}
