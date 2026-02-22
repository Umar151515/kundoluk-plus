import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_info.dart';

class AuthStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;

  AuthStore(this.prefs, this.secureStorage);

  static const String _kAccounts = 'auth_accounts_v5';
  static const String _kActiveId = 'auth_active_id_v5';

  final List<AccountInfo> _accounts = [];
  String? _activeId;

  Box<String>? _cacheBox;
  String? _currentBoxUserId;

  List<AccountInfo> get accounts => List.unmodifiable(_accounts);

  bool get hasAnyAccount => _accounts.isNotEmpty;

  bool get hasActiveAccount => _activeId != null && _accounts.any((a) => a.id == _activeId);

  AccountInfo? get activeAccount => _accounts.where((a) => a.id == _activeId).firstOrNull;

  Future<String?> getToken(String id) => secureStorage.read(key: 'token_$id');
  Future<String?> getPassword(String id) => secureStorage.read(key: 'password_$id');

  Future<void> setTokenPassword(
    String id, {
    String? token,
    String? password,
  }) async {
    if (token != null) await secureStorage.write(key: 'token_$id', value: token);
    if (password != null) {
      await secureStorage.write(key: 'password_$id', value: password);
    }
  }

  Future<void> deleteTokenPassword(String id) async {
    await secureStorage.delete(key: 'token_$id');
    await secureStorage.delete(key: 'password_$id');
  }

  Future<void> loadFromPrefs() async {
    _accounts.clear();
    _activeId = prefs.getString(_kActiveId);

    final raw = prefs.getString(_kAccounts);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final it in decoded) {
            if (it is Map) {
              final a = AccountInfo.fromJson(it.cast<String, dynamic>());
              if (a != null && a.id.isNotEmpty && a.username.isNotEmpty) {
                _accounts.add(a);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (_accounts.isNotEmpty && (_activeId == null || _accounts.every((a) => a.id != _activeId))) {
      _activeId = _accounts.first.id;
      await prefs.setString(_kActiveId, _activeId!);
    }

    await _openCacheBoxForActive();
    notifyListeners();
  }

  Future<void> _persistAccounts() async {
    final list = _accounts.map((e) => e.toJson()).toList();
    await prefs.setString(_kAccounts, jsonEncode(list));
    if (_activeId != null) {
      await prefs.setString(_kActiveId, _activeId!);
    } else {
      await prefs.remove(_kActiveId);
    }
  }

  String _newId(String username) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'acc_${username}_$now';
  }

  Future<void> _openCacheBoxForActive() async {
    final userId = activeAccount?.id;
    if (userId == null) {
      _cacheBox = null;
      _currentBoxUserId = null;
      return;
    }
    if (_currentBoxUserId == userId && _cacheBox?.isOpen == true) return;

    if (_cacheBox != null) {
      await _cacheBox!.close();
    }

    final boxName = 'user_cache_$userId';
    _cacheBox = await Hive.openBox<String>(boxName);
    _currentBoxUserId = userId;
  }

  Future<Box<String>?> getCacheBox() async {
    await _openCacheBoxForActive();
    return _cacheBox;
  }

  Future<void> saveToCache(String key, Map<String, dynamic> data) async {
    final box = await getCacheBox();
    if (box == null) return;
    await box.put(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadFromCache(String key) async {
    final box = await getCacheBox();
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCurrentUserCache() async {
    final box = await getCacheBox();
    await box?.clear();
  }

  Future<void> _deleteUserCache(String userId) async {
    final boxName = 'user_cache_$userId';
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<String>(boxName);
      await box.close();
    }
    await Hive.deleteBoxFromDisk(boxName);
  }

  Future<void> setOrReplaceSession({
    required String username,
    required String token,
    required Map<String, dynamic>? accountJson,
    String? password,
    bool makeActive = true,
  }) async {
    final idx = _accounts.indexWhere((a) => a.username == username);
    final info = AccountInfo(
      id: idx >= 0 ? _accounts[idx].id : _newId(username),
      username: username,
      accountJson: accountJson,
      savedAt: DateTime.now(),
    );

    if (idx >= 0) {
      _accounts[idx] = info;
    } else {
      _accounts.add(info);
    }

    if (makeActive) _activeId = info.id;

    await setTokenPassword(info.id, token: token, password: password);
    await _persistAccounts();
    await _openCacheBoxForActive();
    notifyListeners();
  }

  Future<void> switchActive(String id) async {
    if (_accounts.every((a) => a.id != id)) return;
    _activeId = id;
    await _persistAccounts();
    await _openCacheBoxForActive();
    notifyListeners();
  }

  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    final removedWasActive = _activeId == id;

    if (removedWasActive) {
      _activeId = _accounts.isNotEmpty ? _accounts.first.id : null;
    }

    await _persistAccounts();
    await deleteTokenPassword(id);
    await _deleteUserCache(id);

    await _openCacheBoxForActive();
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final a in _accounts) {
      await deleteTokenPassword(a.id);
      await _deleteUserCache(a.id);
    }
    _accounts.clear();
    _activeId = null;
    await prefs.remove(_kAccounts);
    await prefs.remove(_kActiveId);
    _cacheBox = null;
    _currentBoxUserId = null;
    notifyListeners();
  }

  Future<void> invalidateActiveToken() async {
    final active = activeAccount;
    if (active == null) return;
    await secureStorage.delete(key: 'token_${active.id}');
    notifyListeners();
  }

  Future<void> updateActivePassword(String newPassword) async {
    final active = activeAccount;
    if (active == null) return;
    await secureStorage.write(key: 'password_${active.id}', value: newPassword);
    notifyListeners();
  }
}
