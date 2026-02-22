import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// ----------------------------------------------------------------------
/// Utils / Extensions
/// ----------------------------------------------------------------------
extension DateTimeX on DateTime {
  String toApiDate() => DateFormat('yyyy-MM-dd').format(this);

  bool isSameDate(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  DateTime get dateOnly => DateTime(year, month, day);
}

extension MapX on Map<String, dynamic> {
  int? parseInt(String key) {
    final v = this[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? parseDouble(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool? parseBool(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'да' || s == 'yes';
    }
    return null;
  }

  DateTime? parseDateTime(String key) {
    final v = this[key];
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime? parseDateOnly(String key) {
    final dt = parseDateTime(key);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }
}

extension ListX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

bool isWide(BuildContext context) => MediaQuery.of(context).size.width >= 1000;

/// ----------------------------------------------------------------------
/// Cache Keys
/// ----------------------------------------------------------------------
abstract class CacheKeys {
  static String schedule(DateTime day) => 'schedule:${day.toApiDate()}';
  static String marks(int term, bool absent) =>
      'marks:term=$term:absent=${absent ? 1 : 0}';
  static String quarterMarks() => 'qmarks:all';
}

/// ----------------------------------------------------------------------
/// Offline-first policy (твой подход)
/// - Кэш НЕ предназначен для снижения нагрузки.
/// - Кэш нужен, чтобы:
///   1) показать данные быстро, пока сеть грузится
///   2) показать данные при недоступности API / отсутствии интернета
/// - При сетевой ошибке: если кэш есть — показываем кэш + статус.
///   Если кэша нет — показываем нормальную ошибку/пустую заглушку.
/// ----------------------------------------------------------------------

enum UiNetStatus {
  idle,
  loading,
  offlineUsingCache,
  errorNoCache,
  ok,
}

class _Absent {
  const _Absent();
}
const _absent = _Absent();

@immutable
class ScreenDataState<T> {
  final T cache;
  final UiNetStatus status;
  final ApiFailure? error;

  const ScreenDataState({
    required this.cache,
    required this.status,
    required this.error,
  });

  bool get hasCache {
    final c = cache;
    if (c == null) return false;
    if (c is List) return c.isNotEmpty;
    return true;
  }

  ScreenDataState<T> copyWith({
    Object? cache = _absent, // важно: Object? + sentinel
    UiNetStatus? status,
    ApiFailure? error,
  }) {
    final nextCache = identical(cache, _absent) ? this.cache : cache as T;
    return ScreenDataState<T>(
      cache: nextCache,
      status: status ?? this.status,
      error: error,
    );
  }

  static ScreenDataState<T> initial<T>(T emptyCache) =>
      ScreenDataState(cache: emptyCache, status: UiNetStatus.idle, error: null);
}


/// ----------------------------------------------------------------------
/// main
/// ----------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  const secureStorage = FlutterSecureStorage();
  final prefs = await SharedPreferences.getInstance();

  await initializeDateFormatting('ru_RU', null);
  Intl.defaultLocale = 'ru_RU';

  final settings = AppSettingsStore(prefs);
  await settings.load();

  final auth = AuthStore(prefs, secureStorage);
  await auth.loadFromPrefs();

  final appLock = AppLockStore(prefs);
  await appLock.load();

  final api = KundolukApi(
    dio: Dio(),
    prefs: prefs,
    settings: settings,
    auth: auth,
  );

  runApp(AppRoot(
    settings: settings,
    auth: auth,
    api: api,
    appLock: appLock,
  ));
}

/// ----------------------------------------------------------------------
/// Settings
/// ----------------------------------------------------------------------
class AppSettingsStore extends ChangeNotifier {
  final SharedPreferences prefs;
  AppSettingsStore(this.prefs);

  static const String _kThemeMode = 'theme_mode';
  static const String _kBaseUrl = 'base_url';
  static const String _kUserAgent = 'user_agent';

  static const String kDefaultBaseUrl = 'https://kundoluk.edu.gov.kg/api/';
  static const String kDefaultUserAgent = 'Kundoluk Student Flutter';

  ThemeMode themeMode = ThemeMode.system;
  String baseUrl = kDefaultBaseUrl;
  String userAgent = kDefaultUserAgent;

  Future<void> load() async {
    final tm = prefs.getString(_kThemeMode) ?? 'system';
    themeMode = switch (tm) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    baseUrl = prefs.getString(_kBaseUrl) ?? kDefaultBaseUrl;
    baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    userAgent = prefs.getString(_kUserAgent) ?? kDefaultUserAgent;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_kThemeMode, v);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final fixed = url.trim().isEmpty ? kDefaultBaseUrl : url.trim();
    baseUrl = fixed.endsWith('/') ? fixed : '$fixed/';
    await prefs.setString(_kBaseUrl, baseUrl);
    notifyListeners();
  }

  Future<void> resetBaseUrl() => setBaseUrl(kDefaultBaseUrl);

  Future<void> setUserAgent(String ua) async {
    userAgent = ua.trim().isEmpty ? kDefaultUserAgent : ua.trim();
    await prefs.setString(_kUserAgent, userAgent);
    notifyListeners();
  }

  Future<void> resetUserAgent() => setUserAgent(kDefaultUserAgent);
}

/// ----------------------------------------------------------------------
/// App Lock
/// ----------------------------------------------------------------------
class AppLockStore extends ChangeNotifier {
  final SharedPreferences prefs;
  AppLockStore(this.prefs);

  static const _kEnabled = 'app_lock_enabled';
  static const _kHash = 'app_lock_hash';
  static const _kTimeoutSec = 'app_lock_timeout_sec';

  bool enabled = false;
  String? _hash;
  int timeoutSec = 60;

  bool get hasPasscode => _hash != null && _hash!.isNotEmpty;

  Future<void> load() async {
    enabled = prefs.getBool(_kEnabled) ?? false;
    _hash = prefs.getString(_kHash);
    timeoutSec = prefs.getInt(_kTimeoutSec) ?? 60;
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
    await prefs.remove(_kHash);
    await prefs.setBool(_kEnabled, false);
    notifyListeners();
  }

  bool verify(String passcode) {
    final h = _hash;
    if (h == null || h.isEmpty) return false;
    return _weakHash(passcode.trim()) == h;
  }
}

/// ----------------------------------------------------------------------
/// Root / Gate
/// ----------------------------------------------------------------------
class AppRoot extends StatelessWidget {
  final AppSettingsStore settings;
  final AuthStore auth;
  final KundolukApi api;
  final AppLockStore appLock;

  const AppRoot({
    super.key,
    required this.settings,
    required this.auth,
    required this.api,
    required this.appLock,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([settings, auth, appLock]),
      builder: (_, _) {
        final seed = Colors.indigo;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Кундолук • Ученик',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru', 'RU'),
            Locale('en', 'US'),
          ],
          locale: const Locale('ru', 'RU'),
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            visualDensity: VisualDensity.standard,
            cardTheme: const CardThemeData(elevation: 0),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: seed,
            cardTheme: const CardThemeData(elevation: 0),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          home: AppGate(
            settings: settings,
            auth: auth,
            api: api,
            appLock: appLock,
          ),
        );
      },
    );
  }
}

class AppGate extends StatefulWidget {
  final AppSettingsStore settings;
  final AuthStore auth;
  final KundolukApi api;
  final AppLockStore appLock;

  const AppGate({
    super.key,
    required this.settings,
    required this.auth,
    required this.api,
    required this.appLock,
  });

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.appLock.enabled && widget.appLock.hasPasscode;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldLock = widget.appLock.enabled && widget.appLock.hasPasscode;
    if (shouldLock != _locked) {
      setState(() => _locked = shouldLock);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!(widget.appLock.enabled && widget.appLock.hasPasscode)) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      final t = widget.appLock.timeoutSec;
      if (t <= 0) {
        setState(() => _locked = true);
        return;
      }
      final bgAt = _backgroundedAt;
      if (bgAt != null) {
        final diff = DateTime.now().difference(bgAt).inSeconds;
        if (diff >= t) setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return AppLockScreen(
        appLock: widget.appLock,
        onUnlocked: () => setState(() => _locked = false),
      );
    }

    if (!widget.auth.hasAnyAccount || !widget.auth.hasActiveAccount) {
      return LoginScreen(
        api: widget.api,
        auth: widget.auth,
        settings: widget.settings,
        appLock: widget.appLock,
      );
    }

    return HomeScreen(
      api: widget.api,
      auth: widget.auth,
      settings: widget.settings,
      appLock: widget.appLock,
    );
  }
}

/// ----------------------------------------------------------------------
/// App scaffold helpers
/// ----------------------------------------------------------------------
class AppScaffoldMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const AppScaffoldMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Clipboard helper
/// ----------------------------------------------------------------------
class Copy {
  static Future<void> text(
    BuildContext context,
    String value, {
    String? label,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label != null ? '$label скопировано' : 'Скопировано')),
    );
  }
}
/// ----------------------------------------------------------------------
/// AUTH (multi-accounts) + Secure Storage + per-user Hive cache
/// ----------------------------------------------------------------------
class AccountInfo {
  final String id;
  final String username;
  final Map<String, dynamic>? accountJson;
  final DateTime savedAt;

  AccountInfo({
    required this.id,
    required this.username,
    required this.savedAt,
    this.accountJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'accountJson': accountJson,
        'savedAt': savedAt.toIso8601String(),
      };

  static AccountInfo? fromJson(Map<String, dynamic> json) {
    try {
      return AccountInfo(
        id: (json['id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        accountJson: (json['accountJson'] is Map)
            ? (json['accountJson'] as Map).cast<String, dynamic>()
            : null,
        savedAt: DateTime.tryParse((json['savedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

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

  bool get hasActiveAccount =>
      _activeId != null && _accounts.any((a) => a.id == _activeId);

  AccountInfo? get activeAccount =>
      _accounts.where((a) => a.id == _activeId).firstOrNull;

  Future<String?> getToken(String id) => secureStorage.read(key: 'token_$id');
  Future<String?> getPassword(String id) =>
      secureStorage.read(key: 'password_$id');

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
              if (a != null &&
                  a.id.isNotEmpty &&
                  a.username.isNotEmpty) {
                _accounts.add(a);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (_accounts.isNotEmpty &&
        (_activeId == null || _accounts.every((a) => a.id != _activeId))) {
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
/// ----------------------------------------------------------------------
/// API
/// ----------------------------------------------------------------------
enum ApiErrorKind {
  none,
  network,
  timeout,
  badUrl,
  unauthorized,
  forbidden,
  validation,
  server,
  parse,
  unknown,
}

class ApiFailure implements Exception {
  final ApiErrorKind kind;
  final String title;
  final String message;
  final int? httpStatus;
  final dynamic details;

  ApiFailure({
    required this.kind,
    required this.title,
    required this.message,
    this.httpStatus,
    this.details,
  });

  @override
  String toString() => '$title: $message';
}

class ApiResponse<T> {
  final int resultCode;
  final String message;
  final T data;
  final ApiFailure? failure;

  const ApiResponse({
    required this.resultCode,
    required this.message,
    required this.data,
    this.failure,
  });

  bool get isSuccess => failure == null && resultCode == 0;

  static ApiResponse<T> ok<T>(T data, {String message = 'ОК'}) =>
      ApiResponse(resultCode: 0, message: message, data: data);

  static ApiResponse<T> fail<T>(
    ApiFailure f, {
    int resultCode = -1,
    required T data,
  }) =>
      ApiResponse(
        resultCode: resultCode,
        message: f.message,
        data: data,
        failure: f,
      );
}

class KundolukApi {
  final Dio dio;
  final SharedPreferences prefs;
  final AppSettingsStore settings;
  final AuthStore auth;

  KundolukApi({
    required this.dio,
    required this.prefs,
    required this.settings,
    required this.auth,
  }) {
    dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 25),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['content-type'] = 'application/json';
          options.headers['accept-encoding'] = 'gzip';
          options.headers['host'] = 'kundoluk.edu.gov.kg';
          options.headers['user-agent'] = settings.userAgent;

          final active = auth.activeAccount;
          if (active != null) {
            final token = await auth.getToken(active.id);
            if (token != null && token.isNotEmpty) {
              options.headers['authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await auth.invalidateActiveToken();
          }
          handler.next(e);
        },
      ),
    );
  }

  String get baseUrl => settings.baseUrl;

  ApiFailure _mapDioToFailure(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiFailure(
        kind: ApiErrorKind.timeout,
        title: 'Превышено время ожидания',
        message:
            'Сервер долго отвечает. Проверь интернет и попробуй ещё раз.',
        httpStatus: status,
        details: e.message,
      );
    }

    if (e.type == DioExceptionType.unknown) {
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('failed host lookup')) {
        return ApiFailure(
          kind: ApiErrorKind.network,
          title: 'Нет соединения',
          message: 'Похоже, нет интернета или сервер недоступен.',
          details: e.message,
        );
      }
      if (msg.contains('handshake') || msg.contains('certificate')) {
        return ApiFailure(
          kind: ApiErrorKind.network,
          title: 'Проблема SSL',
          message: 'Не удалось установить защищённое соединение.',
          details: e.message,
        );
      }
      if (msg.contains('invalid')) {
        return ApiFailure(
          kind: ApiErrorKind.badUrl,
          title: 'Неверный адрес API',
          message: 'Проверь Base URL в настройках.',
          details: e.message,
        );
      }
    }

    if (status == 401) {
      return ApiFailure(
        kind: ApiErrorKind.unauthorized,
        title: 'Сессия недействительна',
        message: 'Токен истёк или пароль был изменён. Нужно войти заново.',
        httpStatus: status,
        details: data,
      );
    }
    if (status == 403) {
      return ApiFailure(
        kind: ApiErrorKind.forbidden,
        title: 'Доступ запрещён',
        message: 'Нет прав доступа к этому действию.',
        httpStatus: status,
        details: data,
      );
    }
    if (status == 400) {
      final text = _extractServerErrorMessage(data) ?? 'Неверные данные запроса.';
      return ApiFailure(
        kind: ApiErrorKind.validation,
        title: 'Ошибка данных',
        message: text,
        httpStatus: status,
        details: data,
      );
    }
    if (status != null && status >= 500) {
      return ApiFailure(
        kind: ApiErrorKind.server,
        title: 'Ошибка сервера',
        message: 'Сервер вернул ошибку ($status). Попробуй позже.',
        httpStatus: status,
        details: data,
      );
    }

    return ApiFailure(
      kind: ApiErrorKind.unknown,
      title: 'Ошибка',
      message: 'Не удалось выполнить запрос.',
      httpStatus: status,
      details: data ?? e.message,
    );
  }

  String? _extractServerErrorMessage(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        return _extractServerErrorMessage(decoded);
      }
      if (data is List) {
        final msgs = data
            .map((e) => (e is Map
                ? (e['errorMessage'] ?? e['message'] ?? '').toString()
                : e.toString()))
            .where((s) => s.trim().isNotEmpty)
            .toList();
        if (msgs.isNotEmpty) return msgs.join('; ');
      }
      if (data is Map) {
        final m = data.cast<dynamic, dynamic>();
        final msg = (m['message'] ?? m['resultMessage'] ?? m['errorMessage'])
            ?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg;
      }
    } catch (_) {}
    return null;
  }

  Future<ApiResponse<Account>> loginStudent({
    required String username,
    required String password,
    bool makeActive = true,
  }) async {
    try {
      final url = '${baseUrl}auth/loginStudent';
      final resp = await dio.post(url, data: {
        'username': username,
        'password': password,
        'device': defaultTargetPlatform.name,
      });

      if (resp.statusCode != 200) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка HTTP',
            message: 'HTTP ${resp.statusCode}',
            httpStatus: resp.statusCode,
            details: resp.data,
          ),
          data: Account(),
        );
      }

      final map = _asMap(resp.data);
      final token = (map['token'] ?? '').toString();

      if (token.isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.parse,
            title: 'Ошибка ответа',
            message: 'Не удалось получить токен.',
            details: map,
          ),
          data: Account(),
        );
      }

      final account = Account.fromJson(map);

      await auth.setOrReplaceSession(
        username: username,
        token: token,
        password: password,
        accountJson: map,
        makeActive: makeActive,
      );

      return ApiResponse.ok(account);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapDioToFailure(e), data: Account());
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: Account(),
      );
    }
  }

  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final active = auth.activeAccount;
      if (active == null) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.unauthorized,
            title: 'Нет аккаунта',
            message: 'Сначала войди в аккаунт.',
          ),
          data: null,
        );
      }

      final curr = currentPassword.trim();
      if (curr.isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.validation,
            title: 'Нужен текущий пароль',
            message: 'Введи текущий пароль.',
          ),
          data: null,
        );
      }
      if (newPassword.trim().isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.validation,
            title: 'Новый пароль пустой',
            message: 'Укажи новый пароль.',
          ),
          data: null,
        );
      }

      final url = '${baseUrl}account/changePasswordStudent';
      final resp = await dio.post(url, data: {
        'CurrentPassword': curr,
        'NewPassword': newPassword,
        'NewPasswordConfirmation': newPassword,
      });

      final map = _asMap(resp.data);
      final code = map.parseInt('resultCode') ?? 0;
      final msg = (map['resultMessage'] ?? map['message'] ?? '').toString();

      if (resp.statusCode != 200) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка HTTP',
            message: 'HTTP ${resp.statusCode}',
            httpStatus: resp.statusCode,
            details: resp.data,
          ),
          data: null,
        );
      }

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.validation,
            title: 'Не удалось сменить пароль',
            message: msg.isEmpty ? 'Ошибка смены пароля.' : msg,
            details: map,
          ),
          resultCode: code,
          data: null,
        );
      }

      await auth.updateActivePassword(newPassword);
      return ApiResponse.ok(null, message: msg.isEmpty ? 'Пароль изменён' : msg);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapDioToFailure(e), data: null);
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: null,
      );
    }
  }

  Future<ApiResponse<void>> ensureAuthorized() async {
    final active = auth.activeAccount;
    if (active == null) {
      return ApiResponse.fail(
        ApiFailure(
          kind: ApiErrorKind.unauthorized,
          title: 'Нет аккаунта',
          message: 'Сначала войди в аккаунт.',
        ),
        data: null,
      );
    }

    final token = await auth.getToken(active.id);
    if (token == null || token.isEmpty) {
      final password = await auth.getPassword(active.id);
      if (password == null || password.isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.unauthorized,
            title: 'Нужно войти заново',
            message: 'Токен недействителен. Пароль не сохранён — войди заново.',
          ),
          data: null,
        );
      }
      final relogin = await loginStudent(
        username: active.username,
        password: password,
        makeActive: true,
      );
      if (!relogin.isSuccess) {
        return ApiResponse.fail(relogin.failure!, data: null);
      }
    }
    return ApiResponse.ok(null);
  }

  Future<ApiResponse<DailySchedule?>> getDailySchedule(DateTime day) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) return ApiResponse.fail(authOk.failure!, data: null);

    try {
      final start = day.toApiDate();
      final end = day.toApiDate();

      final resp = await dio.get(
        '${baseUrl}student/gradebook/list',
        queryParameters: {'start_date': start, 'end_date': end},
      );

      final json = _asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка API',
            message: msg.isEmpty ? 'Ошибка API (resultCode=$code)' : msg,
            details: json,
          ),
          resultCode: code,
          data: null,
        );
      }

      final list = _asList(action);
      final lessons = list
          .map((e) => Lesson.fromJson(_asMap(e)))
          .whereType<Lesson>()
          .toList()
        ..sort((a, b) =>
            (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));

      final schedule = DailySchedule(date: day.dateOnly, lessons: lessons);

      await auth.saveToCache(CacheKeys.schedule(day), json);
      return ApiResponse.ok(schedule, message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapDioToFailure(e), data: null);
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: null,
      );
    }
  }

  Future<ApiResponse<DailySchedule?>> getFullScheduleDay(DateTime day) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) {
      return ApiResponse.fail(authOk.failure!, data: null);
    }

    final scheduleResp = await getDailySchedule(day);
    if (!scheduleResp.isSuccess) return scheduleResp;

    final dailySchedule = scheduleResp.data;
    if (dailySchedule == null) return ApiResponse.ok(null);

    final term = SchoolYear.getQuarter(day, nearest: true) ?? 1;

    final results = await Future.wait([
      getScheduleWithMarks(term, absent: false),
      getScheduleWithMarks(term, absent: true),
    ]);

    final marksResp = results[0];
    final absentResp = results[1];

    if (!marksResp.isSuccess && !absentResp.isSuccess) {
      return ApiResponse.fail(
        marksResp.failure ?? absentResp.failure!,
        data: null,
      );
    }

    final extraLessons = <Lesson>[];
    if (marksResp.isSuccess) {
      final mDay = marksResp.data.getByDate(day);
      if (mDay != null) extraLessons.addAll(mDay.lessons);
    }
    if (absentResp.isSuccess) {
      final aDay = absentResp.data.getByDate(day);
      if (aDay != null) extraLessons.addAll(aDay.lessons);
    }

    final marksByLessonUid = <String, List<Mark>>{};
    for (final lesson in extraLessons) {
      final uid = lesson.uid;
      if (uid == null || uid.isEmpty) continue;
      if (lesson.marks.isEmpty) continue;
      marksByLessonUid.putIfAbsent(uid, () => []).addAll(lesson.marks);
    }

    final mergedLessons = dailySchedule.lessons.map((lesson) {
      final uid = lesson.uid;
      if (uid != null && marksByLessonUid.containsKey(uid)) {
        final uniqueMarks = _uniqueMarks(marksByLessonUid[uid]!);
        return lesson.copyWith(marks: uniqueMarks);
      }
      return lesson;
    }).toList();

    mergedLessons.sort((a, b) =>
        (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));

    return ApiResponse.ok(
      DailySchedule(date: dailySchedule.date, lessons: mergedLessons),
      message: 'Расписание обновлено',
    );
  }

  List<Mark> _uniqueMarks(List<Mark> marks) {
    final map = <String, Mark>{};
    for (final m in marks) {
      final key = m.uid ??
          '${m.createdAt?.toIso8601String() ?? ''}:'
              '${m.value ?? ''}:'
              '${m.customMark ?? ''}:'
              '${m.absent ?? ''}:'
              '${m.lateMinutes ?? ''}:'
              '${m.absentType ?? ''}';
      map[key] = m;
    }
    final result = map.values.toList();
    result.sort((a, b) =>
        (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    return result;
  }

  Future<ApiResponse<DailySchedules>> getScheduleWithMarks(
    int term, {
    required bool absent,
  }) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) {
      return ApiResponse.fail(
        authOk.failure!,
        data: const DailySchedules(days: []),
      );
    }

    try {
      final resp = await dio.get(
        '${baseUrl}student/gradebook/term/$term',
        queryParameters: {'absent': absent ? 1 : 0},
      );

      final json = _asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка API',
            message: msg.isEmpty ? 'Ошибка API (resultCode=$code)' : msg,
            details: json,
          ),
          resultCode: code,
          data: const DailySchedules(days: []),
        );
      }

      final list = _asList(action);
      final lessons = list
          .map((e) => Lesson.fromJson(_asMap(e)))
          .whereType<Lesson>()
          .toList();

      final daysMap = <DateTime, List<Lesson>>{};
      for (final l in lessons) {
        final d = l.lessonDay?.toLocal();
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        daysMap.putIfAbsent(day, () => []).add(l);
      }

      final days = daysMap.entries
          .map((e) {
            final ls = [...e.value]
              ..sort((a, b) =>
                  (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
            return DailySchedule(date: e.key, lessons: ls);
          })
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final schedules = DailySchedules(days: days);

      await auth.saveToCache(CacheKeys.marks(term, absent), json);
      return ApiResponse.ok(schedules, message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(
        _mapDioToFailure(e),
        data: const DailySchedules(days: []),
      );
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: const DailySchedules(days: []),
      );
    }
  }

  Future<ApiResponse<List<QuarterMark>>> getAllQuarterMarks() async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) return ApiResponse.fail(authOk.failure!, data: const []);

    try {
      final resp = await dio.get('${baseUrl}student/qmarks/all');

      final json = _asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка API',
            message: msg.isEmpty ? 'Ошибка API (resultCode=$code)' : msg,
            details: json,
          ),
          resultCode: code,
          data: const [],
        );
      }

      final results = _asList(action);
      final all = <QuarterMark>[];
      for (final r in results) {
        final rm = _asMap(r);
        final qms = _asList(rm['quarterMarks']);
        for (final q in qms) {
          final qm = QuarterMark.fromJson(_asMap(q));
          if (qm != null) all.add(qm);
        }
      }

      final uniq = <String, QuarterMark>{};
      for (final m in all) {
        final id = m.objectId ??
            '${m.subjectNameRu}:${m.quarter}:${m.quarterMark}:${m.customMark}';
        uniq[id] = m;
      }

      final out = uniq.values.toList()
        ..sort((a, b) {
          final sA = a.subjectNameRu ?? a.subjectNameKg ?? '';
          final sB = b.subjectNameRu ?? b.subjectNameKg ?? '';
          final c = sA.compareTo(sB);
          if (c != 0) return c;
          return (a.quarter ?? 0).compareTo(b.quarter ?? 0);
        });

      await auth.saveToCache(CacheKeys.quarterMarks(), json);
      return ApiResponse.ok(out, message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapDioToFailure(e), data: const []);
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: const [],
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return _asMap(decoded);
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static List<dynamic> _asList(dynamic v) => v is List ? v : const [];
}

/// ----------------------------------------------------------------------
/// Models
/// ----------------------------------------------------------------------
class Account {
  final String? userId;
  final String? studentId;
  final String? okpo;
  final int? pin;
  final String? pinAsString;
  final int? grade;
  final String? letter;
  final String? lastName;
  final String? firstName;
  final String? midName;
  final String? email;
  final String? phone;
  final bool? isAgreementSigned;
  final String? locale;
  final bool? changePassword;
  final String? role;
  final DateTime? birthdate;
  final School? school;

  Account({
    this.userId,
    this.studentId,
    this.okpo,
    this.pin,
    this.pinAsString,
    this.grade,
    this.letter,
    this.lastName,
    this.firstName,
    this.midName,
    this.email,
    this.phone,
    this.isAgreementSigned,
    this.locale,
    this.changePassword,
    this.role,
    this.birthdate,
    this.school,
  });

  String get fio => [
        lastName,
        firstName,
        midName,
      ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).join(' ').trim();

  String get classLabel => '${grade ?? '?'}${letter ?? ''}';

  static Account fromJson(Map<String, dynamic> json) {
    String? pickStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return null;
    }

    final schoolJson = json['school'];
    return Account(
      userId: pickStr(['userId', 'user_id']),
      studentId: pickStr(['studentId', 'student_id']),
      okpo: pickStr(['okpo']),
      pin: json.parseInt('pin'),
      pinAsString: pickStr(['pinAsString', 'pin_as_string']),
      grade: json.parseInt('grade'),
      letter: pickStr(['letter']),
      lastName: pickStr(['last_name', 'lastName', 'lastNameRu']),
      firstName: pickStr(['first_name', 'firstName']),
      midName: pickStr(['mid_name', 'midName']),
      email: pickStr(['email']),
      phone: pickStr(['phone']),
      isAgreementSigned: json.parseBool('isAgreementSigned'),
      locale: pickStr(['locale']),
      changePassword: json.parseBool('changePassword'),
      role: pickStr(['type', 'role']),
      birthdate: json.parseDateTime('birthdate'),
      school: schoolJson is Map ? School.fromJson(schoolJson.cast<String, dynamic>()) : null,
    );
  }
}

class School {
  final String? schoolId;
  final String? institutionId;
  final String? okpo;
  final String? nameRu;
  final String? shortName;
  final bool? isStaffActive;

  School({
    this.schoolId,
    this.institutionId,
    this.okpo,
    this.nameRu,
    this.shortName,
    this.isStaffActive,
  });

  static School fromJson(Map<String, dynamic> json) => School(
        schoolId: (json['schoolId'] ?? json['school_id'])?.toString(),
        institutionId: (json['institutionId'] ?? json['institution_id'])?.toString(),
        okpo: json['okpo']?.toString(),
        nameRu: (json['nameRu'] ?? json['name_ru'])?.toString(),
        shortName: (json['short'] ?? json['shortName'])?.toString(),
        isStaffActive: json.parseBool('isStaffActive'),
      );
}

class DailySchedules {
  final List<DailySchedule> days;
  const DailySchedules({required this.days});

  DailySchedule? getByDate(DateTime date) {
    final d = date.dateOnly;
    for (final x in days) {
      if (x.date.dateOnly == d) return x;
    }
    return null;
  }
}

class DailySchedule {
  final DateTime date;
  final List<Lesson> lessons;
  const DailySchedule({required this.date, required this.lessons});
}

class Lesson {
  final String? uid;
  final String? scheduleItemId;
  final LessonTeacher? teacher;
  final Subject? subject;
  final Room? room;
  final String? startTime;
  final String? endTime;
  final String? lessonTime;
  final DateTime? lessonDay;
  final int? year;
  final int? month;
  final int? day;
  final int? lessonNumber;
  final StudentInfo? student;
  final List<Mark> marks;
  final Topic? topic;
  final Task? task;
  final Task? lastTask;
  final String? okpo;
  final String? gradeId;
  final int? grade;
  final String? letter;
  final bool? isKrujok;
  final int? group;
  final String? groupId;
  final String? subjectGroupName;
  final int? shift;
  final int? dayOfWeek;
  final String? schoolId;
  final String? schoolNameKg;
  final String? schoolNameRu;
  final bool? isContentSubject;
  final bool? isTwelve;
  final int? orderIndex;

  Lesson({
    this.uid,
    this.scheduleItemId,
    this.teacher,
    this.subject,
    this.room,
    this.startTime,
    this.endTime,
    this.lessonTime,
    this.lessonDay,
    this.year,
    this.month,
    this.day,
    this.lessonNumber,
    this.student,
    this.marks = const [],
    this.topic,
    this.task,
    this.lastTask,
    this.okpo,
    this.gradeId,
    this.grade,
    this.letter,
    this.isKrujok,
    this.group,
    this.groupId,
    this.subjectGroupName,
    this.shift,
    this.dayOfWeek,
    this.schoolId,
    this.schoolNameKg,
    this.schoolNameRu,
    this.isContentSubject,
    this.isTwelve,
    this.orderIndex,
  });

  Lesson copyWith({List<Mark>? marks}) {
    return Lesson(
      uid: uid,
      scheduleItemId: scheduleItemId,
      teacher: teacher,
      subject: subject,
      room: room,
      startTime: startTime,
      endTime: endTime,
      lessonTime: lessonTime,
      lessonDay: lessonDay,
      year: year,
      month: month,
      day: day,
      lessonNumber: lessonNumber,
      student: student,
      marks: marks ?? this.marks,
      topic: topic,
      task: task,
      lastTask: lastTask,
      okpo: okpo,
      gradeId: gradeId,
      grade: grade,
      letter: letter,
      isKrujok: isKrujok,
      group: group,
      groupId: groupId,
      subjectGroupName: subjectGroupName,
      shift: shift,
      dayOfWeek: dayOfWeek,
      schoolId: schoolId,
      schoolNameKg: schoolNameKg,
      schoolNameRu: schoolNameRu,
      isContentSubject: isContentSubject,
      isTwelve: isTwelve,
      orderIndex: orderIndex,
    );
  }

  static Lesson? fromJson(Map<String, dynamic> json) {
    final teacherJson = json['teacher'];
    final subjectJson = json['subject'];
    final roomJson = json['roomData'];
    final studentJson = json['student'];
    final marksJson = json['marks'];
    final topicJson = json['topic'];
    final taskJson = json['task'];
    final lastTaskJson = json['lastTask'];

    final marks = (marksJson is List)
        ? marksJson
            .map((e) => Mark.fromJson(e is Map ? e.cast<String, dynamic>() : {}))
            .whereType<Mark>()
            .toList()
        : <Mark>[];

    return Lesson(
      uid: json['uid']?.toString(),
      scheduleItemId: json['scheduleItemId']?.toString(),
      teacher: teacherJson is Map
          ? LessonTeacher.fromJson(teacherJson.cast<String, dynamic>())
          : null,
      subject: subjectJson is Map
          ? Subject.fromJson(subjectJson.cast<String, dynamic>())
          : null,
      room: roomJson is Map
          ? Room.fromJson(roomJson.cast<String, dynamic>())
          : null,
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      lessonTime: json['lessonTime']?.toString(),
      lessonDay: json.parseDateTime('lessonDay'),
      year: json.parseInt('year'),
      month: json.parseInt('month'),
      day: json.parseInt('day'),
      lessonNumber: json.parseInt('lesson'),
      student: studentJson is Map
          ? StudentInfo.fromJson(studentJson.cast<String, dynamic>())
          : null,
      marks: marks,
      topic: topicJson is Map ? Topic.fromJson(topicJson.cast<String, dynamic>()) : null,
      task: taskJson is Map ? Task.fromJson(taskJson.cast<String, dynamic>()) : null,
      lastTask: lastTaskJson is Map ? Task.fromJson(lastTaskJson.cast<String, dynamic>()) : null,
      okpo: json['okpo']?.toString(),
      gradeId: json['gradeId']?.toString(),
      grade: json.parseInt('grade'),
      letter: json['letter']?.toString(),
      isKrujok: json.parseBool('isKrujok'),
      group: json.parseInt('group'),
      groupId: json['groupId']?.toString(),
      subjectGroupName: json['subjectGroupName']?.toString(),
      shift: json.parseInt('shift'),
      dayOfWeek: json.parseInt('dayOfWeek'),
      schoolId: json['school']?.toString(),
      schoolNameKg: json['schoolNameKg']?.toString(),
      schoolNameRu: json['schoolNameRu']?.toString(),
      isContentSubject: json.parseBool('isContentSubject'),
      isTwelve: json.parseBool('isTwelve'),
      orderIndex: json.parseInt('orderIndex'),
    );
  }
}

class LessonTeacher {
  final int? pin;
  final String? pinAsString;
  final String? firstName;
  final String? lastName;
  final String? midName;

  LessonTeacher({this.pin, this.pinAsString, this.firstName, this.lastName, this.midName});

  String get fio => [
        lastName,
        firstName,
        midName,
      ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).join(' ');

  static LessonTeacher fromJson(Map<String, dynamic> json) {
    return LessonTeacher(
      pin: json.parseInt('pin'),
      pinAsString: (json['pinAsString'] ?? json['pin_as_string'])?.toString(),
      firstName: (json['firstName'] ?? json['first_name'])?.toString(),
      lastName: (json['lastName'] ?? json['last_name'])?.toString(),
      midName: (json['midName'] ?? json['mid_name'])?.toString(),
    );
  }
}

class Subject {
  final String? code;
  final String? name;
  final String? nameKg;
  final String? nameRu;
  final String? short;
  final String? shortKg;
  final String? shortRu;
  final int? grade;

  Subject({this.code, this.name, this.nameKg, this.nameRu, this.short, this.shortKg, this.shortRu, this.grade});

  static Subject fromJson(Map<String, dynamic> json) {
    return Subject(
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      nameKg: json['nameKg']?.toString(),
      nameRu: json['nameRu']?.toString(),
      short: json['short']?.toString(),
      shortKg: json['shortKg']?.toString(),
      shortRu: json['shortRu']?.toString(),
      grade: json.parseInt('grade'),
    );
  }
}

class Room {
  final String? idRoom;
  final String? roomName;
  final int? floor;
  final String? block;

  Room({this.idRoom, this.roomName, this.floor, this.block});

  static Room fromJson(Map<String, dynamic> json) {
    return Room(
      idRoom: json['id']?.toString(),
      roomName: (json['roomName'] ?? json['room_name'])?.toString(),
      floor: json.parseInt('floor'),
      block: json['block']?.toString(),
    );
  }
}

class Task {
  final int? code;
  final String? name;
  final String? note;
  final DateTime? lessonDay;

  Task({this.code, this.name, this.note, this.lessonDay});

  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      code: json.parseInt('code'),
      name: json['name']?.toString(),
      note: json['note']?.toString(),
      lessonDay: json.parseDateOnly('lessonDay'),
    );
  }
}

class Topic {
  final int? code;
  final String? name;
  final String? short;
  final DateTime? lessonDay;

  Topic({this.code, this.name, this.short, this.lessonDay});

  static Topic fromJson(Map<String, dynamic> json) {
    return Topic(
      code: json.parseInt('code'),
      name: json['name']?.toString(),
      short: json['short']?.toString(),
      lessonDay: json.parseDateOnly('lessonDay'),
    );
  }
}

class StudentInfo {
  final String? scheduleItemId;
  final DateTime? lessonDay;
  final DateTime? lessonDayAsDateOnly;
  final String? objectId;
  final String? schoolId;
  final String? gradeId;
  final String? okpo;
  final int? pin;
  final String? pinAsString;
  final int? grade;
  final String? letter;
  final String? name;
  final String? lastName;
  final String? firstName;
  final String? midName;
  final String? email;
  final String? phone;
  final String? groupId;
  final String? subjectGroupName;
  final String? districtName;
  final String? cityName;

  StudentInfo({
    this.scheduleItemId,
    this.lessonDay,
    this.lessonDayAsDateOnly,
    this.objectId,
    this.schoolId,
    this.gradeId,
    this.okpo,
    this.pin,
    this.pinAsString,
    this.grade,
    this.letter,
    this.name,
    this.lastName,
    this.firstName,
    this.midName,
    this.email,
    this.phone,
    this.groupId,
    this.subjectGroupName,
    this.districtName,
    this.cityName,
  });

  static StudentInfo fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      scheduleItemId: json['scheduleItemId']?.toString(),
      lessonDay: json.parseDateTime('lessonDay'),
      lessonDayAsDateOnly: json.parseDateOnly('lessonDayAsDateOnly'),
      objectId: json['objectId']?.toString(),
      schoolId: json['schoolId']?.toString(),
      gradeId: json['gradeId']?.toString(),
      okpo: json['okpo']?.toString(),
      pin: json.parseInt('pin'),
      pinAsString: json['pinAsString']?.toString(),
      grade: json.parseInt('grade'),
      letter: json['letter']?.toString(),
      name: json['name']?.toString(),
      lastName: json['lastName']?.toString(),
      firstName: json['firstName']?.toString(),
      midName: json['midName']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      groupId: json['groupId']?.toString(),
      subjectGroupName: json['subjectGroupName']?.toString(),
      districtName: json['districtName']?.toString(),
      cityName: json['cityName']?.toString(),
    );
  }
}

class Mark {
  final String? markId;
  final String? lsUid;
  final String? uid;
  final String? studentId;
  final int? studentPin;
  final String? studentPinAsString;
  final String? firstName;
  final String? lastName;
  final String? midName;
  final int? value;
  final String? markType;
  final int? oldMark;
  final String? customMark;
  final bool? absent;
  final String? absentType;
  final String? absentReason;
  final int? lateMinutes;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? success;

  Mark({
    this.markId,
    this.lsUid,
    this.uid,
    this.studentId,
    this.studentPin,
    this.studentPinAsString,
    this.firstName,
    this.lastName,
    this.midName,
    this.value,
    this.markType,
    this.oldMark,
    this.customMark,
    this.absent,
    this.absentType,
    this.absentReason,
    this.lateMinutes,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.success,
  });

  static Mark? fromJson(Map<String, dynamic> json) {
    return Mark(
      markId: json['mark_id']?.toString(),
      lsUid: json['ls_uid']?.toString(),
      uid: json['uid']?.toString(),
      studentId: json['idStudent']?.toString(),
      studentPin: json.parseInt('student_pin'),
      studentPinAsString: json['student_pin_as_string']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      midName: json['mid_name']?.toString(),
      value: json.parseInt('mark'),
      markType: json['mark_type']?.toString(),
      oldMark: json.parseInt('old_mark'),
      customMark: json['custom_mark']?.toString(),
      absent: json.parseBool('absent'),
      absentType: json['absent_type']?.toString(),
      absentReason: json['absent_reason']?.toString(),
      lateMinutes: json.parseInt('late_minutes'),
      note: json['note']?.toString(),
      createdAt: json.parseDateTime('created_at'),
      updatedAt: json.parseDateTime('updated_at'),
      success: json.parseBool('success'),
    );
  }

  bool get isNumericMark => value != null && value! > 0;
}

class QuarterMark {
  final String? objectId;
  final String? gradeId;
  final String? studentId;
  final String? subjectId;
  final int? quarter;
  final double? quarterAvg;
  final int? quarterMark;
  final String? customMark;
  final bool? isBonus;
  final DateTime? quarterDate;
  final String? subjectNameKg;
  final String? subjectNameRu;
  final String? staffId;

  QuarterMark({
    this.objectId,
    this.gradeId,
    this.studentId,
    this.subjectId,
    this.quarter,
    this.quarterAvg,
    this.quarterMark,
    this.customMark,
    this.isBonus,
    this.quarterDate,
    this.subjectNameKg,
    this.subjectNameRu,
    this.staffId,
  });

  static QuarterMark? fromJson(Map<String, dynamic> json) {
    return QuarterMark(
      objectId: json['objectId']?.toString(),
      gradeId: json['gradeId']?.toString(),
      studentId: json['studentId']?.toString(),
      subjectId: json['subjectId']?.toString(),
      quarter: json.parseInt('quarter'),
      quarterAvg: json.parseDouble('quarterAvg'),
      quarterMark: json.parseInt('quarterMark'),
      customMark: json['customMark']?.toString(),
      isBonus: json.parseBool('isBonus'),
      quarterDate: json.parseDateTime('quarterDate'),
      subjectNameKg: json['subjectNameKg']?.toString(),
      subjectNameRu: json['subjectNameRu']?.toString(),
      staffId: json['staffId']?.toString(),
    );
  }
}

class MarkEntry {
  final Mark mark;
  final Lesson? lesson;
  final DateTime lessonDate;

  MarkEntry({required this.mark, required this.lesson, required this.lessonDate});

  String get subjectName => lesson?.subject?.nameRu ?? lesson?.subject?.name ?? 'Предмет';
  String? get teacherName => lesson?.teacher?.fio;
  String? get lessonTime =>
      (lesson?.startTime != null && lesson?.endTime != null) ? '${lesson?.startTime}–${lesson?.endTime}' : null;

  DateTime? get markCreated => mark.createdAt ?? mark.updatedAt;

  String get label => MarkUi.label(mark);
}

/// ----------------------------------------------------------------------
/// School year
/// ----------------------------------------------------------------------
class SchoolYear {
  static const Map<int, Map<String, List<int>>> quarters = {
    1: {'start': [9, 1], 'end': [11, 4]},
    2: {'start': [11, 10], 'end': [12, 30]},
    3: {'start': [1, 12], 'end': [3, 5]},
    4: {'start': [3, 9], 'end': [5, 31]},
  };

  static int? getQuarter(DateTime target, {bool nearest = false}) {
    final yearStart = target.month >= 9 ? target.year : target.year - 1;

    final qDates = <int, (DateTime, DateTime)>{};
    for (final entry in quarters.entries) {
      final q = entry.key;
      final start = entry.value['start']!;
      final end = entry.value['end']!;
      final y = q <= 2 ? yearStart : yearStart + 1;
      qDates[q] = (DateTime(y, start[0], start[1]), DateTime(y, end[0], end[1]));
    }

    final td = target.dateOnly;

    for (final e in qDates.entries) {
      final (s, en) = e.value;
      if (!td.isBefore(s) && !td.isAfter(en)) return e.key;
    }

    if (!nearest) return null;

    int bestQ = 1;
    int bestDiff = 1 << 30;
    for (final e in qDates.entries) {
      final (s, en) = e.value;
      final d1 = (td.difference(s).inDays).abs();
      final d2 = (td.difference(en).inDays).abs();
      final d = min(d1, d2);
      if (d < bestDiff) {
        bestDiff = d;
        bestQ = e.key;
      }
    }
    return bestQ;
  }

  static bool isVacation(DateTime target) => getQuarter(target, nearest: false) == null;
}

/// ----------------------------------------------------------------------
/// UI atoms: Chips, Info table, Offline banner
/// ----------------------------------------------------------------------
class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoRow {
  final String label;
  final String? value;
  _InfoRow(this.label, this.value);
}

class _InfoTable extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = items.where((e) => e.value != null && e.value!.trim().isNotEmpty && e.value != 'null').toList();

    if (filtered.isEmpty) return Text('Нет данных', style: TextStyle(color: cs.onSurfaceVariant));

    return Column(
      children: filtered.map((e) {
        final value = e.value!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 150,
              child: Text(
                e.label,
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: SelectableText(value)),
          ]),
        );
      }).toList(),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const OfflineBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.errorContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onErrorContainer)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: cs.onErrorContainer.withValues(alpha: 0.9))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onErrorContainer,
              side: BorderSide(color: cs.onErrorContainer.withValues(alpha: 0.6)),
            ),
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }
}
/// ----------------------------------------------------------------------
/// App Lock Screen
/// ----------------------------------------------------------------------
class AppLockScreen extends StatefulWidget {
  final AppLockStore appLock;
  final VoidCallback onUnlocked;
  const AppLockScreen({
    super.key,
    required this.appLock,
    required this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _ctrl = TextEditingController();
  bool _bad = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    final ok = widget.appLock.verify(_ctrl.text);
    if (!ok) {
      setState(() => _bad = true);
      return;
    }
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: AppScaffoldMaxWidth(
          maxWidth: 520,
          child: Center(
            child: Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(
                    children: [
                      Icon(Icons.lock_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Доступ к приложению',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    obscureText: true,
                    autofocus: true,
                    onSubmitted: (_) => _tryUnlock(),
                    decoration: InputDecoration(
                      labelText: 'Пароль / PIN',
                      errorText: _bad ? 'Неверный пароль' : null,
                      prefixIcon: const Icon(Icons.password_rounded),
                    ),
                    onChanged: (_) {
                      if (_bad) setState(() => _bad = false);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _tryUnlock,
                      child: const Text('Разблокировать'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Login Screen
/// ----------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  final AppSettingsStore settings;
  final AppLockStore appLock;

  const LoginScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.appLock,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  ApiFailure? _failure;

  @override
  void initState() {
    super.initState();
    if (widget.auth.activeAccount != null) {
      _username.text = widget.auth.activeAccount!.username;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login({bool makeActive = true}) async {
    setState(() {
      _failure = null;
      _loading = true;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _loading = false);
      return;
    }

    final resp = await widget.api.loginStudent(
      username: _username.text.trim(),
      password: _password.text,
      makeActive: makeActive,
    );

    if (!mounted) return;

    if (!resp.isSuccess) {
      setState(() {
        _failure = resp.failure;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          api: widget.api,
          auth: widget.auth,
          settings: widget.settings,
          appLock: widget.appLock,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(settings: widget.settings, appLock: widget.appLock),
    );
  }

  Future<void> _openAccounts() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AccountsSheet(api: widget.api, auth: widget.auth, settings: widget.settings),
    );
    if (!mounted) return;
    if (widget.auth.hasActiveAccount) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(api: widget.api, auth: widget.auth, settings: widget.settings, appLock: widget.appLock),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final header = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.school_rounded, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Кундолук • Ученик',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Аккаунты',
            onPressed: _openAccounts,
            icon: Icon(Icons.switch_account_rounded, color: cs.onPrimaryContainer),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: _openSettings,
            icon: Icon(Icons.settings_rounded, color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );

    final accountsHint = widget.auth.accounts.isNotEmpty
        ? Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: ListTile(
              leading: const Icon(Icons.account_circle_rounded),
              title: const Text('Есть сохранённые аккаунты'),
              subtitle: Text('Аккаунтов: ${widget.auth.accounts.length}.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openAccounts,
            ),
          )
        : const SizedBox.shrink();

    final form = Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Логин (обычно ПИН)',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введи логин' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Введи пароль' : null,
              ),
              const SizedBox(height: 14),
              if (_failure != null)
                ErrorCard(
                  failure: _failure!,
                  onCopy: () => Copy.text(context, _failure.toString(), label: 'Ошибка'),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : () => _login(makeActive: true),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: AppScaffoldMaxWidth(
          maxWidth: 760,
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 860;
              if (!wide) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      header,
                      const SizedBox(height: 14),
                      if (widget.auth.accounts.isNotEmpty) accountsHint,
                      if (widget.auth.accounts.isNotEmpty) const SizedBox(height: 12),
                      form,
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        header,
                        const SizedBox(height: 14),
                        accountsHint,
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: cs.surfaceContainerHighest,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Можно хранить несколько аккаунтов и переключаться.\n'
                              'В настройках можно поставить пароль на вход в приложение.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: form),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Accounts Sheet
/// ----------------------------------------------------------------------
class AccountsSheet extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  final AppSettingsStore settings;

  const AccountsSheet({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
  });

  @override
  State<AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends State<AccountsSheet> {
  ApiFailure? _failure;
  bool _loading = false;

  Future<void> _switchTo(AccountInfo acc) async {
    setState(() {
      _failure = null;
      _loading = true;
    });

    await widget.auth.switchActive(acc.id);

    final ok = await widget.api.ensureAuthorized();
    if (!mounted) return;

    if (!ok.isSuccess) {
      setState(() {
        _failure = ok.failure;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);
    Navigator.pop(context);
  }

  Future<void> _remove(AccountInfo acc) async {
    await widget.auth.removeAccount(acc.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _clearAll() async {
    await widget.auth.clearAll();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _addAccount() async {
    final res = await showDialog<_LoginDialogResult>(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );

    if (!mounted) return;
    if (res == null) return;

    setState(() {
      _failure = null;
      _loading = true;
    });

    final resp = await widget.api.loginStudent(
      username: res.username,
      password: res.password,
      makeActive: res.makeActive,
    );

    if (!mounted) return;

    if (!resp.isSuccess) {
      setState(() {
        _failure = resp.failure;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);
    if (res.makeActive) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.auth.activeAccount;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.switch_account_rounded),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Аккаунты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Добавить аккаунт',
                    onPressed: _loading ? null : _addAccount,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_failure != null) ...[
                ErrorCard(failure: _failure!, onCopy: () => Copy.text(context, _failure.toString(), label: 'Ошибка')),
                const SizedBox(height: 10),
              ],
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
              if (widget.auth.accounts.isEmpty)
                Text('Аккаунтов нет. Добавь аккаунт.', style: TextStyle(color: cs.onSurfaceVariant))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.auth.accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final acc = widget.auth.accounts[i];
                      final isActive = active?.id == acc.id;
                      final account = acc.accountJson != null ? Account.fromJson(acc.accountJson!) : null;

                      final subtitle = [
                        if (account != null && account.classLabel.trim().isNotEmpty) 'Класс: ${account.classLabel}',
                        if ((account?.fio ?? '').trim().isNotEmpty) account!.fio,
                      ].where((x) => x.trim().isNotEmpty).join(' • ');

                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isActive ? cs.primary : cs.outlineVariant),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive ? cs.primaryContainer : cs.surfaceContainerHigh,
                            foregroundColor: isActive ? cs.onPrimaryContainer : cs.onSurface,
                            child: Text(_getInitials(acc), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(acc.username, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive) Icon(Icons.check_circle_rounded, color: cs.primary),
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: _loading ? null : () => _remove(acc),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                          onTap: _loading ? null : () => _switchTo(acc),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.auth.accounts.isEmpty ? null : _clearAll,
                      child: const Text('Удалить все'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(AccountInfo acc) {
    if (acc.accountJson != null) {
      try {
        final account = Account.fromJson(acc.accountJson!);
        if (account.firstName != null && account.firstName!.isNotEmpty) {
          return account.firstName![0].toUpperCase();
        }
        if (account.fio.isNotEmpty) {
          final firstWord = account.fio.split(' ').first;
          if (firstWord.isNotEmpty) return firstWord[0].toUpperCase();
        }
      } catch (_) {}
    }
    if (acc.username.isNotEmpty) return acc.username[0].toUpperCase();
    return '?';
  }
}

class _LoginDialogResult {
  final String username;
  final String password;
  final bool makeActive;
  _LoginDialogResult(this.username, this.password, this.makeActive);
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _makeActive = true;

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить аккаунт'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _u,
              decoration: const InputDecoration(labelText: 'Логин', prefixIcon: Icon(Icons.person_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _p,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock_rounded)),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              value: _makeActive,
              onChanged: (v) => setState(() => _makeActive = v),
              title: const Text('Сделать активным'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final u = _u.text.trim();
            final p = _p.text;
            if (u.isEmpty || p.isEmpty) return;
            Navigator.pop(context, _LoginDialogResult(u, p, _makeActive));
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------
/// Home shell
/// ----------------------------------------------------------------------
enum HomeTab { today, marks, quarterMarks, profile }

class HomeScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  final AppSettingsStore settings;
  final AppLockStore appLock;

  const HomeScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.appLock,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.today;
  late final VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _authListener = () {
      if (mounted) setState(() {});
    };
    widget.auth.addListener(_authListener);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _openAccounts() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AccountsSheet(api: widget.api, auth: widget.auth, settings: widget.settings),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(settings: widget.settings, appLock: widget.appLock),
    );
    if (!mounted) return;
    setState(() {});
  }

  String _getTabTitle() {
    return switch (_tab) {
      HomeTab.today => 'Расписание',
      HomeTab.marks => 'Оценки',
      HomeTab.quarterMarks => 'Итоги',
      HomeTab.profile => 'Профиль',
    };
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.activeAccount?.accountJson != null
        ? Account.fromJson(widget.auth.activeAccount!.accountJson!)
        : null;

    final tabTitle = _getTabTitle();
    final displayName = account?.fio.isNotEmpty == true ? account!.fio : widget.auth.activeAccount?.username;
    final classLabel = account?.classLabel;

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tabTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (classLabel != null && classLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Класс: $classLabel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (displayName != null && displayName.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        toolbarHeight: 80,
        actions: [
          IconButton(tooltip: 'Аккаунты', onPressed: _openAccounts, icon: const Icon(Icons.switch_account_rounded)),
          IconButton(tooltip: 'Настройки', onPressed: _openSettings, icon: const Icon(Icons.settings_rounded)),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_tab) {
            HomeTab.today => TodayScreen(
                key: ValueKey('today_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
              ),
            HomeTab.marks => MarksScreen(
                key: ValueKey('marks_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
              ),
            HomeTab.quarterMarks => QuarterMarksScreen(
                key: ValueKey('qm_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
              ),
            HomeTab.profile => ProfileScreen(
                key: ValueKey('profile_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
                appLock: widget.appLock,
              ),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = HomeTab.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Сегодня'),
          NavigationDestination(icon: Icon(Icons.grade_rounded), label: 'Оценки'),
          NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Итоги'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }
}
/// ----------------------------------------------------------------------
/// Unified empty / error views
/// ----------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _EmptyView({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_rounded, size: 44, color: cs.onSurfaceVariant),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                SelectableText(subtitle, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onRetry, child: const Text('Обновить')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ApiErrorView extends StatelessWidget {
  final ApiFailure failure;
  final VoidCallback onRetry;
  final bool vacationHint;

  const ApiErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.vacationHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String hint = '';
    if (failure.kind == ApiErrorKind.badUrl) {
      hint = 'Открой настройки и проверь Base URL.';
    } else if (failure.kind == ApiErrorKind.network) {
      hint = 'Проверь интернет или попробуй позже.';
    } else if (failure.kind == ApiErrorKind.unauthorized) {
      hint = 'Сессия недействительна. Перелогинься (в профиле/аккаунтах).';
    } else if (vacationHint) {
      hint = 'Также возможно, что это каникулы (дата вне четвертей).';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failure.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cs.onErrorContainer),
                  ),
                  const SizedBox(height: 8),
                  Text(failure.message, style: TextStyle(color: cs.onErrorContainer)),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(hint, style: TextStyle(color: cs.onErrorContainer.withValues(alpha: 0.9))),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(onPressed: onRetry, child: const Text('Повторить')),
                      OutlinedButton(
                        onPressed: () => Copy.text(context, failure.toString(), label: 'Ошибка'),
                        child: const Text('Копировать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final ApiFailure failure;
  final VoidCallback onCopy;

  const ErrorCard({super.key, required this.failure, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(failure.title, style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(failure.message, style: TextStyle(color: cs.onErrorContainer)),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(onPressed: onCopy, child: const Text('Копировать')),
        ]),
      ]),
    );
  }
}

/// ----------------------------------------------------------------------
/// TODAY (offline-first: cache always shown if exists; errors only if no cache)
/// ----------------------------------------------------------------------
class TodayScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const TodayScreen({super.key, required this.api, required this.auth});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selected;
  late DateTime _today;

  ScreenDataState<DailySchedule?> _state = ScreenDataState.initial<DailySchedule?>(null);

  static const int _totalDays = 178;
  late final List<DateTime> _dateList;
  static const double _chipW = 80;
  static const double _chipPad = 8;
  static const double _itemExtent = _chipW + _chipPad;

  final ScrollController _datesCtrl = ScrollController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    if (_today.weekday == DateTime.sunday) {
      _selected = _today.add(const Duration(days: 1));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сегодня воскресенье — показан понедельник')),
        );
      });
    } else {
      _selected = _today;
    }

    _dateList = _generateDateList(_today);

    WidgetsBinding.instance.addPostFrameCallback((_) => _centerDateInRibbon(_selected));

    _bootstrap();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _datesCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadFromCache();
    unawaited(_fetchFromNetwork());
  }

  bool _isConnectivityish(ApiFailure? f) {
    final k = f?.kind;
    return k == ApiErrorKind.network || k == ApiErrorKind.timeout || k == ApiErrorKind.badUrl;
  }

  Future<void> _loadFromCache() async {
    final key = CacheKeys.schedule(_selected);
    final json = await widget.auth.loadFromCache(key);

    DailySchedule? parsed;
    if (json != null) {
      try {
        final action = json.containsKey('actionResult') ? json['actionResult'] : json;
        final list = (action as List?) ?? const [];
        final lessons = list
            .map((e) => Lesson.fromJson(KundolukApi._asMap(e)))
            .whereType<Lesson>()
            .toList()
          ..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
        parsed = DailySchedule(date: _selected.dateOnly, lessons: lessons);
      } catch (_) {
        parsed = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(cache: parsed, status: _state.status, error: _state.error);
    });
  }

  Future<void> _fetchFromNetwork() async {
    setState(() {
      _state = _state.copyWith(status: UiNetStatus.loading, error: null);
    });

    final resp = await widget.api.getFullScheduleDay(_selected);

    if (!mounted) return;

    if (resp.isSuccess) {
      setState(() {
        _state = ScreenDataState<DailySchedule?>(
          cache: resp.data,
          status: UiNetStatus.ok,
          error: null,
        );
      });
      return;
    }

    final f = resp.failure;
    final hasCache = _state.hasCache;

    if (hasCache) {
      setState(() {
        _state = _state.copyWith(
          status: UiNetStatus.offlineUsingCache,
          error: f,
        );
      });
      return;
    }

    setState(() {
      _state = _state.copyWith(
        status: UiNetStatus.errorNoCache,
        error: f,
      );
    });
  }

  void _onPickDate(DateTime d) {
    setState(() {
      _selected = d.dateOnly;
      _state = ScreenDataState.initial<DailySchedule?>(null);
    });
    unawaited(_bootstrap());
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateCenterDate(d));
  }

  Future<void> _pickDateFromCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      locale: const Locale('ru', 'RU'),
      helpText: 'Выбери дату',
      confirmText: 'ОК',
      cancelText: 'Отмена',
    );

    if (picked == null) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    if (d.weekday == DateTime.sunday) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Воскресенье — выходной, выбери другой день')));
      return;
    }
    _onPickDate(d);
  }

  void _goToToday() {
    DateTime target = _today;
    if (_today.weekday == DateTime.sunday) {
      target = _today.add(const Duration(days: 1));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сегодня воскресенье — показан понедельник')));
    }
    _onPickDate(target);
  }

  List<DateTime> _generateDateList(DateTime today) {
    final half = _totalDays ~/ 2;

    DateTime start = today;
    int countBefore = 0;
    while (countBefore < half) {
      start = start.subtract(const Duration(days: 1));
      if (start.weekday != DateTime.sunday) countBefore++;
    }

    DateTime end = today;
    int countAfter = 0;
    while (countAfter < half) {
      end = end.add(const Duration(days: 1));
      if (end.weekday != DateTime.sunday) countAfter++;
    }

    final result = <DateTime>[];
    DateTime current = start;
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.sunday) {
        result.add(current.dateOnly);
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  int _indexOfDate(DateTime date) => _dateList.indexWhere((d) => d.isSameDate(date));

  void _centerDateInRibbon(DateTime date) {
    if (!_datesCtrl.hasClients) return;
    final idx = _indexOfDate(date);
    if (idx < 0) return;

    final viewport = _datesCtrl.position.viewportDimension;
    final target = idx * _itemExtent - (viewport / 2) + (_itemExtent / 2);

    final maxExtent = _datesCtrl.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxExtent);
    _datesCtrl.jumpTo(clamped);
  }

  void _animateCenterDate(DateTime date) {
    if (!_datesCtrl.hasClients) return;
    final idx = _indexOfDate(date);
    if (idx < 0) return;

    final viewport = _datesCtrl.position.viewportDimension;
    final target = idx * _itemExtent - (viewport / 2) + (_itemExtent / 2);

    final maxExtent = _datesCtrl.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxExtent);

    _datesCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dfTitle = DateFormat('d MMMM, EEE');

    final schedule = _state.cache;

    final showOfflineBanner = _state.status == UiNetStatus.offlineUsingCache;
    final offlineReason = _state.error;
    final offlineSubtitle = offlineReason == null
        ? 'Показаны сохранённые данные.'
        : _isConnectivityish(offlineReason)
            ? 'Нет сети/сервер недоступен. Показаны сохранённые данные.'
            : 'API вернул ошибку. Показаны сохранённые данные.';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          snap: true,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          titleSpacing: 16,
          title: Text(
            dfTitle.format(_selected),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(tooltip: 'Сегодня', onPressed: _goToToday, icon: const Icon(Icons.today_rounded)),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Выбрать дату',
              onPressed: _pickDateFromCalendar,
              icon: const Icon(Icons.calendar_month_rounded),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Обновить',
              onPressed: _fetchFromNetwork,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(62),
            child: Column(
              children: [
                SizedBox(
                  height: 58,
                  child: ListView.builder(
                    key: const PageStorageKey<String>('dates_list'),
                    controller: _datesCtrl,
                    scrollDirection: Axis.horizontal,
                    itemCount: _dateList.length,
                    itemBuilder: (_, i) {
                      final date = _dateList[i];
                      final isToday = date.isSameDate(_today);
                      final isSelected = date.isSameDate(_selected);
                      final isVacation = SchoolYear.isVacation(date);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: DateChip(
                          date: date,
                          isToday: isToday,
                          isSelected: isSelected,
                          isVacation: isVacation,
                          onTap: () {
                            if (date.isSameDate(_selected)) return;
                            _onPickDate(date);
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_state.status == UiNetStatus.loading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),

        if (showOfflineBanner)
          SliverToBoxAdapter(
            child: OfflineBanner(
              title: 'Офлайн',
              subtitle: offlineSubtitle,
              onRetry: _fetchFromNetwork,
            ),
          ),

        if (_state.status == UiNetStatus.errorNoCache && schedule == null)
          SliverFillRemaining(
            child: ApiErrorView(
              failure: _state.error ??
                  ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: 'Не удалось загрузить данные'),
              onRetry: _fetchFromNetwork,
              vacationHint: SchoolYear.isVacation(_selected),
            ),
          )
        else if (schedule == null && _state.status != UiNetStatus.loading)
          SliverFillRemaining(
            child: _EmptyView(
              title: 'Нет данных',
              subtitle: SchoolYear.isVacation(_selected)
                  ? 'Сейчас каникулы.'
                  : 'На этот день расписание пустое или ещё не загружено.',
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (schedule != null && schedule.lessons.isEmpty)
          SliverFillRemaining(
            child: _EmptyView(
              title: 'Уроков нет',
              subtitle: SchoolYear.isVacation(_selected) ? 'Сейчас каникулы.' : 'На этот день расписание пустое.',
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (schedule != null)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final l = schedule.lessons[i];
                final now = DateTime.now();
                final isCurrent = _isCurrentLesson(l, now, _selected);
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LessonDetailsScreen(lesson: l)),
                  ),
                  child: CompactLessonCard(lesson: l, isCurrent: isCurrent),
                );
              },
              childCount: schedule.lessons.length,
            ),
          ),
      ],
    );
  }

  bool _isCurrentLesson(Lesson l, DateTime now, DateTime selectedDay) {
    if (!selectedDay.isSameDate(now)) return false;
    final s = _parseTime(selectedDay, l.startTime);
    final e = _parseTime(selectedDay, l.endTime);
    if (s == null || e == null) return false;
    return (now.isAfter(s) || now.isAtSameMomentAs(s)) && (now.isBefore(e) || now.isAtSameMomentAs(e));
  }

  DateTime? _parseTime(DateTime day, String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }
}

class DateChip extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isVacation;
  final VoidCallback onTap;

  const DateChip({
    super.key,
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isVacation,
    required this.onTap,
  });

  String _getMonthAbbr() => DateFormat.MMM('ru').format(date).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final wd = DateFormat('EE', 'ru').format(date);
    final day = date.day.toString();
    final month = _getMonthAbbr();

    final Color bg = isSelected
        ? cs.primaryContainer
        : isVacation
            ? cs.errorContainer.withValues(alpha: 0.55)
            : cs.surfaceContainerHighest;

    final Color fg = isSelected
        ? cs.onPrimaryContainer
        : isVacation
            ? cs.onErrorContainer
            : cs.onSurface;

    final border = BorderSide(
      color: isToday ? cs.primary : cs.outlineVariant,
      width: isToday ? 2 : 1,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 80,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              wd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11, height: 1.0),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(month, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12, height: 1.0)),
                const SizedBox(width: 2),
                Text(day, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 13, height: 1.0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// MARKS (offline-first + consistent UI)
/// ----------------------------------------------------------------------
enum MarksSortMode { bySubject, byTeacherTime, byLessonDate }

class MarksScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const MarksScreen({super.key, required this.api, required this.auth});

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  int _term = SchoolYear.getQuarter(DateTime.now(), nearest: true) ?? 1;
  MarksSortMode _sort = MarksSortMode.bySubject;

  ScreenDataState<List<MarkEntry>> _state =
    ScreenDataState.initial<List<MarkEntry>>(<MarkEntry>[]);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadFromCache();
    unawaited(_fetchFromNetwork());
  }

  List<MarkEntry> _uniqueEntries(List<MarkEntry> entries) {
    final map = <String, MarkEntry>{};
    for (final e in entries) {
      final k = e.mark.uid ??
          '${e.lesson?.uid ?? ''}:${e.lessonDate.toIso8601String()}:${e.mark.createdAt?.toIso8601String() ?? ''}:${e.mark.value ?? ''}:${e.mark.customMark ?? ''}:${e.mark.absent ?? ''}:${e.mark.lateMinutes ?? ''}:${e.mark.absentType ?? ''}';
      map[k] = e;
    }
    return map.values.toList();
  }

  Future<void> _loadFromCache() async {
    final keyAbsent = CacheKeys.marks(_term, true);
    final keyPresent = CacheKeys.marks(_term, false);

    final entries = <MarkEntry>[];

    Future<void> addFromCache(String key) async {
      final json = await widget.auth.loadFromCache(key);
      if (json == null) return;

      try {
        final action = json.containsKey('actionResult') ? json['actionResult'] : json;
        final list = (action as List?) ?? const [];
        final lessons = list
            .map((e) => Lesson.fromJson(KundolukApi._asMap(e)))
            .whereType<Lesson>()
            .toList();

        for (final l in lessons) {
          for (final m in l.marks) {
            final d = l.lessonDay?.toLocal();
            if (d == null) continue;
            entries.add(MarkEntry(
              mark: m,
              lesson: l,
              lessonDate: DateTime(d.year, d.month, d.day),
            ));
          }
        }
      } catch (_) {}
    }

    await addFromCache(keyPresent);
    await addFromCache(keyAbsent);

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        cache: _uniqueEntries(entries),
        status: _state.status,
        error: _state.error,
      );
    });
  }

  Future<void> _fetchFromNetwork() async {
    setState(() {
      _state = _state.copyWith(status: UiNetStatus.loading, error: null);
    });

    final marksResp = await widget.api.getScheduleWithMarks(_term, absent: false);
    final absentResp = await widget.api.getScheduleWithMarks(_term, absent: true);

    if (!mounted) return;

    if (marksResp.isSuccess && absentResp.isSuccess) {
      final entries = <MarkEntry>[];

      void addFrom(DailySchedules ds) {
        for (final day in ds.days) {
          for (final lesson in day.lessons) {
            for (final mark in lesson.marks) {
              entries.add(MarkEntry(mark: mark, lesson: lesson, lessonDate: day.date));
            }
          }
        }
      }

      addFrom(marksResp.data);
      addFrom(absentResp.data);

      setState(() {
        _state = ScreenDataState<List<MarkEntry>>(
          cache: _uniqueEntries(entries),
          status: UiNetStatus.ok,
          error: null,
        );
      });
      return;
    }

    final failure = marksResp.failure ?? absentResp.failure;
    final hasCache = _state.hasCache;

    if (hasCache) {
      setState(() {
        _state = _state.copyWith(status: UiNetStatus.offlineUsingCache, error: failure);
      });
    } else {
      setState(() {
        _state = _state.copyWith(status: UiNetStatus.errorNoCache, error: failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = _state.cache;
    final showOfflineBanner = _state.status == UiNetStatus.offlineUsingCache;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          snap: true,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          titleSpacing: 16,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_rounded),
                          const SizedBox(width: 10),
                          const Text('Четверть:', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _term,
                            underline: const SizedBox.shrink(),
                            items: [1, 2, 3, 4].map((q) => DropdownMenuItem(value: q, child: Text('$q'))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _term = v;
                                _state = const ScreenDataState(cache: <MarkEntry>[], status: UiNetStatus.idle, error: null);
                              });
                              unawaited(_bootstrap());
                            },
                          ),
                          const Spacer(),
                          IconButton(tooltip: 'Обновить', onPressed: _fetchFromNetwork, icon: const Icon(Icons.refresh_rounded)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: DropdownButton<MarksSortMode>(
                      value: _sort,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      borderRadius: BorderRadius.circular(16),
                      items: const [
                        DropdownMenuItem(
                          value: MarksSortMode.bySubject,
                          child: Row(
                            children: [
                              Icon(Icons.subject_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('По предметам'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: MarksSortMode.byTeacherTime,
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('По времени'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: MarksSortMode.byLessonDate,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('По дате урока'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _sort = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_state.status == UiNetStatus.loading) const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ),
        ),

        if (showOfflineBanner)
          SliverToBoxAdapter(
            child: OfflineBanner(
              title: 'Офлайн',
              subtitle: 'Показаны сохранённые оценки. Нажми «Обновить», когда появится сеть.',
              onRetry: _fetchFromNetwork,
            ),
          ),

        if (_state.status == UiNetStatus.errorNoCache && data.isEmpty)
          SliverFillRemaining(
            child: ApiErrorView(
              failure: _state.error ??
                  ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: 'Не удалось загрузить оценки'),
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (data.isEmpty && _state.status != UiNetStatus.loading)
          SliverFillRemaining(
            child: _EmptyView(
              title: 'Пусто',
              subtitle: 'За выбранную четверть данных нет (или они ещё не загружены).',
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (_sort == MarksSortMode.bySubject)
          _buildSubjectGroupedSliver(data)
        else
          _buildFlatMarksList(data),
      ],
    );
  }

  Widget _buildFlatMarksList(List<MarkEntry> data) {
    final sorted = [...data];
    if (_sort == MarksSortMode.byTeacherTime) {
      sorted.sort((a, b) => (b.markCreated ?? DateTime(1970)).compareTo(a.markCreated ?? DateTime(1970)));
    } else {
      sorted.sort((a, b) => b.lessonDate.compareTo(a.lessonDate));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = sorted[index];
          return _buildMarkEntryCard(entry, _sort);
        },
        childCount: sorted.length,
      ),
    );
  }

  Widget _buildSubjectGroupedSliver(List<MarkEntry> data) {
    final bySubject = <String, List<MarkEntry>>{};
    for (final e in data) {
      final s = e.subjectName.trim();
      bySubject.putIfAbsent(s, () => []).add(e);
    }
    final subjects = bySubject.keys.toList()..sort();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, subjectIndex) {
          final subject = subjects[subjectIndex];
          final entries = bySubject[subject]!;
          final sortedEntries = [...entries]..sort((a, b) {
              final dateCompare = a.lessonDate.compareTo(b.lessonDate);
              if (dateCompare != 0) return dateCompare;
              return (a.markCreated ?? DateTime(1970)).compareTo(b.markCreated ?? DateTime(1970));
            });

          final stats = MarkStats.ofEntries(sortedEntries);
          final cs = Theme.of(context).colorScheme;

          return Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    if (stats.avg != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          'Средняя: ${stats.avg!.toStringAsFixed(2)}',
                          style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Всего: ${stats.total} • Оценок: ${stats.numericCount} • Отметок: ${stats.notesCount}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sortedEntries.take(60).map((entry) => MarkChip(entry: entry)).toList(),
                  ),
                  if (sortedEntries.length > 60) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Показаны первые 60 из ${sortedEntries.length}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        childCount: subjects.length,
      ),
    );
  }

  Widget _buildMarkEntryCard(MarkEntry entry, MarksSortMode mode) {
    String subtitle;
    if (mode == MarksSortMode.byTeacherTime) {
      final dt = entry.markCreated?.toLocal();
      final when = dt != null ? DateFormat('d MMM HH:mm').format(dt) : 'неизвестно';
      final type = MarkUi.typeTitle(entry.mark);
      subtitle = 'Выставлено: $when • $type • ${entry.label}';
    } else {
      final d = DateFormat('d MMM').format(entry.lessonDate);
      final type = MarkUi.typeTitle(entry.mark);
      subtitle = 'Дата урока: $d • $type • ${entry.label}';
    }

    final cs = Theme.of(context).colorScheme;
    final subject = entry.subjectName;
    final teacher = entry.teacherName;
    final value = entry.label;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: entry.lesson == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonDetailsScreen(lesson: entry.lesson!))),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Text(
                value,
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                if (teacher != null && teacher.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Учитель: $teacher', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ]),
            ),
            if (entry.lesson != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class MarkChip extends StatelessWidget {
  final MarkEntry entry;
  const MarkChip({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final label = entry.label;
    final colors = MarkUi.colors(context, entry.mark);

    return Tooltip(
      message: MarkUi.tooltip(entry),
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: colors.fg, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// QUARTER MARKS (offline-first)
/// ----------------------------------------------------------------------
class QuarterMarksScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const QuarterMarksScreen({super.key, required this.api, required this.auth});

  @override
  State<QuarterMarksScreen> createState() => _QuarterMarksScreenState();
}

class _QuarterMarksScreenState extends State<QuarterMarksScreen> {
  ScreenDataState<List<QuarterMark>> _state =
    ScreenDataState.initial<List<QuarterMark>>(<QuarterMark>[]);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadFromCache();
    unawaited(_fetchFromNetwork());
  }

  List<QuarterMark> _unique(List<QuarterMark> list) {
    final map = <String, QuarterMark>{};
    for (final m in list) {
      final id = m.objectId ?? '${m.subjectNameRu}:${m.quarter}:${m.quarterMark}:${m.customMark}';
      map[id] = m;
    }
    return map.values.toList()
      ..sort((a, b) {
        final sA = a.subjectNameRu ?? a.subjectNameKg ?? '';
        final sB = b.subjectNameRu ?? b.subjectNameKg ?? '';
        final c = sA.compareTo(sB);
        if (c != 0) return c;
        return (a.quarter ?? 0).compareTo(b.quarter ?? 0);
      });
  }

  Future<void> _loadFromCache() async {
    final key = CacheKeys.quarterMarks();
    final json = await widget.auth.loadFromCache(key);

    List<QuarterMark> parsed = const [];
    if (json != null) {
      try {
        final action = json.containsKey('actionResult') ? json['actionResult'] : json;
        final results = (action as List?) ?? const [];
        final all = <QuarterMark>[];
        for (final r in results) {
          final rm = KundolukApi._asMap(r);
          final qms = (rm['quarterMarks'] as List?) ?? const [];
          for (final q in qms) {
            final qm = QuarterMark.fromJson(KundolukApi._asMap(q));
            if (qm != null) all.add(qm);
          }
        }
        parsed = _unique(all);
      } catch (_) {
        parsed = const [];
      }
    }

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(cache: parsed, status: _state.status, error: _state.error);
    });
  }

  Future<void> _fetchFromNetwork() async {
    setState(() => _state = _state.copyWith(status: UiNetStatus.loading, error: null));

    final resp = await widget.api.getAllQuarterMarks();
    if (!mounted) return;

    if (resp.isSuccess) {
      setState(() {
        _state = ScreenDataState<List<QuarterMark>>(cache: resp.data, status: UiNetStatus.ok, error: null);
      });
    } else {
      if (_state.hasCache) {
        setState(() => _state = _state.copyWith(status: UiNetStatus.offlineUsingCache, error: resp.failure));
      } else {
        setState(() => _state = _state.copyWith(status: UiNetStatus.errorNoCache, error: resp.failure));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _state.cache;
    final showOfflineBanner = _state.status == UiNetStatus.offlineUsingCache;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          snap: true,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          titleSpacing: 16,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(66),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.emoji_events_rounded),
                  title: const Text('Итоговые/четвертные оценки'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_state.status == UiNetStatus.loading)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      IconButton(tooltip: 'Обновить', onPressed: _fetchFromNetwork, icon: const Icon(Icons.refresh_rounded)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        if (showOfflineBanner)
          SliverToBoxAdapter(
            child: OfflineBanner(
              title: 'Офлайн',
              subtitle: 'Показаны сохранённые итоги.',
              onRetry: _fetchFromNetwork,
            ),
          ),

        if (_state.status == UiNetStatus.errorNoCache && data.isEmpty)
          SliverFillRemaining(
            child: ApiErrorView(
              failure: _state.error ??
                  ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: 'Не удалось загрузить итоги'),
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (data.isEmpty && _state.status != UiNetStatus.loading)
          SliverFillRemaining(
            child: _EmptyView(
              title: 'Оценок нет',
              subtitle: 'Сервер не вернул четвертные оценки или данные ещё не загружены.',
              onRetry: _fetchFromNetwork,
            ),
          )
        else
          _buildQuarterSliver(data),
      ],
    );
  }

  Widget _buildQuarterSliver(List<QuarterMark> data) {
    final cs = Theme.of(context).colorScheme;

    final bySubject = <String, List<QuarterMark>>{};
    for (final m in data) {
      final subject = (m.subjectNameRu ?? m.subjectNameKg ?? 'Неизвестный предмет').trim();
      bySubject.putIfAbsent(subject, () => []).add(m);
    }
    final subjects = bySubject.keys.toList()..sort();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final subject = subjects[index];
          final list = [...bySubject[subject]!]..sort((a, b) => (a.quarter ?? 0).compareTo(b.quarter ?? 0));

          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: list.map((m) => QuarterChip(mark: m, subjectName: subject)).toList(),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: subjects.length,
      ),
    );
  }
}

class QuarterChip extends StatelessWidget {
  final QuarterMark mark;
  final String subjectName;
  const QuarterChip({super.key, required this.mark, required this.subjectName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = mark.quarter ?? 0;

    final qLabel = (q == 5)
        ? 'Год'
        : (q >= 1 && q <= 4)
            ? '$q четв.'
            : '—';

    final value = mark.quarterMark?.toString() ?? '—';
    final tip = QuarterUi.tooltip(subjectName, mark);

    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qLabel, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                if (mark.isBonus == true) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 18, color: cs.tertiary),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuarterUi {
  static String tooltip(String subjectName, QuarterMark m) {
    final parts = <String>[];
    parts.add('Предмет: $subjectName');

    final q = m.quarter;
    final qLabel = (q == 5)
        ? 'Год'
        : (q != null && q >= 1 && q <= 4)
            ? '$q четверть'
            : '—';
    parts.add('Период: $qLabel');

    final value = m.customMark?.trim().isNotEmpty == true ? m.customMark! : (m.quarterMark?.toString() ?? '—');
    parts.add('Итог: $value');

    if (m.quarterAvg != null) parts.add('Средний: ${m.quarterAvg!.toStringAsFixed(2)}');
    if (m.isBonus == true) parts.add('Бонус: да');

    if (m.quarterDate != null) {
      parts.add('Дата выставления: ${DateFormat('d MMM yyyy, HH:mm').format(m.quarterDate!.toLocal())}');
    }

    return parts.join('\n');
  }
}

/// ----------------------------------------------------------------------
/// PROFILE + Change password
/// ----------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  final KundolukApi api;
  final AuthStore auth;
  final AppLockStore appLock;

  const ProfileScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.appLock,
  });

  Future<void> _openChangePassword(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ChangePasswordSheet(api: api, auth: auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final account = auth.activeAccount?.accountJson != null ? Account.fromJson(auth.activeAccount!.accountJson!) : null;

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  child: const Icon(Icons.person_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      account?.fio.isNotEmpty == true ? account!.fio : 'Ученик',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (account != null) _Chip(label: 'Класс', value: account.classLabel),
                        if (auth.activeAccount?.username != null) _Chip(label: 'Логин', value: auth.activeAccount!.username),
                        if (account?.pinAsString != null) _Chip(label: 'ПИН', value: account!.pinAsString!),
                      ],
                    ),
                    if (account?.school?.nameRu != null) ...[
                      const SizedBox(height: 8),
                      Text(account!.school!.nameRu!, style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Сменить пароль аккаунта'),
                subtitle: const Text('Текущий пароль нужно ввести обязательно'),
                onTap: () => _openChangePassword(context),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.switch_account_rounded),
                title: const Text('Переключить аккаунт'),
                subtitle: Text('Аккаунтов: ${auth.accounts.length}'),
                onTap: () => showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => AccountsSheet(api: api, auth: auth, settings: api.settings),
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Очистить кэш текущего пользователя'),
                subtitle: const Text('Удалить сохранённые ответы API на устройстве'),
                onTap: () async {
                  await auth.clearCurrentUserCache();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Кэш очищен.')));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Выйти из активного аккаунта'),
                subtitle: const Text('Удалить токен этого аккаунта (остальные останутся)'),
                onTap: () async {
                  await auth.invalidateActiveToken();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Токен очищен. Нужно войти заново.')));
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: const Text('Удалить все аккаунты'),
                subtitle: const Text('Сбросить все сохранённые аккаунты и выйти'),
                onTap: () async {
                  await auth.clearAll();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => LoginScreen(api: api, auth: auth, settings: api.settings, appLock: appLock)),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
        if (account != null) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Данные аккаунта', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  _InfoTable(
                    items: [
                      _InfoRow('User ID', account.userId),
                      _InfoRow('Student ID', account.studentId),
                      _InfoRow('ОКПО', account.okpo ?? account.school?.okpo),
                      _InfoRow('Роль', account.role),
                      _InfoRow('Язык', account.locale),
                      _InfoRow('Email', account.email),
                      _InfoRow('Телефон', account.phone),
                      _InfoRow('Дата рождения', account.birthdate != null ? DateFormat('d MMMM yyyy').format(account.birthdate!.toLocal()) : null),
                      _InfoRow('Требует смены пароля', account.changePassword?.toString()),
                      _InfoRow('Соглашение подписано', account.isAgreementSigned?.toString()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return isWide(context) ? AppScaffoldMaxWidth(maxWidth: 980, child: content) : content;
  }
}

class ChangePasswordSheet extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const ChangePasswordSheet({super.key, required this.api, required this.auth});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _loading = false;
  ApiFailure? _failure;
  String? _success;

  @override
  void dispose() {
    _current.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _failure = null;
      _success = null;
      _loading = true;
    });

    final curr = _current.text;
    final n1 = _new1.text.trim();
    final n2 = _new2.text.trim();

    if (curr.trim().isEmpty) {
      setState(() {
        _failure = ApiFailure(kind: ApiErrorKind.validation, title: 'Нужен текущий пароль', message: 'Введи текущий пароль.');
        _loading = false;
      });
      return;
    }

    if (n1.isEmpty) {
      setState(() {
        _failure = ApiFailure(kind: ApiErrorKind.validation, title: 'Новый пароль пустой', message: 'Введи новый пароль.');
        _loading = false;
      });
      return;
    }

    if (n1 != n2) {
      setState(() {
        _failure = ApiFailure(kind: ApiErrorKind.validation, title: 'Пароли не совпадают', message: 'Повтори новый пароль точно так же.');
        _loading = false;
      });
      return;
    }

    final resp = await widget.api.changePassword(currentPassword: curr, newPassword: n1);

    if (!mounted) return;

    if (!resp.isSuccess) {
      setState(() {
        _failure = resp.failure;
        _loading = false;
      });
      return;
    }

    setState(() {
      _success = resp.message.isNotEmpty ? resp.message : 'Пароль изменён';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(
                leading: Icon(Icons.password_rounded),
                title: Text('Смена пароля'),
                subtitle: Text('Текущий пароль нужно вводить всегда'),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
              TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Текущий пароль',
                  prefixIcon: Icon(Icons.lock_rounded),
                  helperText: 'Обязательно',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _new1,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль', prefixIcon: Icon(Icons.key_rounded)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _new2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Повтори новый пароль', prefixIcon: Icon(Icons.key_rounded)),
              ),
              const SizedBox(height: 12),
              if (_failure != null) ErrorCard(failure: _failure!, onCopy: () => Copy.text(context, _failure.toString(), label: 'Ошибка')),
              if (_success != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_success!, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('Закрыть'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: _loading ? null : _submit, child: const Text('Сменить'))),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Lesson cards + details
/// ----------------------------------------------------------------------
class CompactLessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isCurrent;

  const CompactLessonCard({super.key, required this.lesson, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subject = lesson.subject?.nameRu ?? lesson.subject?.name ?? 'Предмет';
    final teacher = lesson.teacher?.fio ?? 'Учитель';
    final room = lesson.room?.roomName;
    final time = (lesson.startTime != null && lesson.endTime != null) ? '${lesson.startTime}–${lesson.endTime}' : 'Время не указано';

    final topic = lesson.topic?.name?.trim();
    final topicLine = (topic != null && topic.isNotEmpty) ? topic : null;

    final Color cardColor = isCurrent ? cs.primaryContainer.withValues(alpha: 0.7) : cs.surfaceContainerHighest;
    final Color leftBorderColor = isCurrent ? cs.primary : Colors.transparent;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      elevation: isCurrent ? 2 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      color: cardColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: leftBorderColor, width: 6)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _LessonNumberPill(num: lesson.lessonNumber),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subject, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(time, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.secondary)),
              ]),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(30)),
                child: Text('Сейчас', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onPrimary)),
              ),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.person_rounded, text: teacher),
              if (room != null && room.trim().isNotEmpty) _InfoPill(icon: Icons.room_rounded, text: room),
            ],
          ),
          if (lesson.marks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: lesson.marks.map((m) => _MarkChipCompact(mark: m)).toList()),
          ],
          if (topicLine != null) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.menu_book_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  topicLine,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
          if (lesson.task != null && (lesson.task!.name ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.home_rounded, size: 18, color: cs.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lesson.task!.name!,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
          if (lesson.lastTask != null && (lesson.lastTask!.name ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.history_rounded, size: 18, color: cs.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lesson.lastTask!.name!,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _LessonNumberPill extends StatelessWidget {
  final int? num;
  const _LessonNumberPill({required this.num});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Text('${num ?? '?'}', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ]),
    );
  }
}

class _MarkChipCompact extends StatelessWidget {
  final Mark mark;
  const _MarkChipCompact({required this.mark});

  @override
  Widget build(BuildContext context) {
    final label = MarkUi.label(mark);
    final colors = MarkUi.colors(context, mark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: colors.fg, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class LessonDetailsScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonDetailsScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subject = lesson.subject?.nameRu ?? lesson.subject?.name ?? 'Предмет';
    final time = (lesson.startTime != null && lesson.endTime != null) ? '${lesson.startTime}–${lesson.endTime}' : null;
    final date = lesson.lessonDay != null ? DateFormat('d MMMM yyyy, EEE').format(lesson.lessonDay!.toLocal()) : null;

    final page = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (time != null) _Chip(label: 'Время', value: time),
                if (date != null) _Chip(label: 'Дата', value: date),
                _Chip(label: 'Номер', value: 'Урок №${lesson.lessonNumber ?? '?'}'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        if (lesson.teacher != null)
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Учитель'),
              subtitle: Text(lesson.teacher!.fio),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeacherDetailsScreen(teacher: lesson.teacher!))),
            ),
          ),
        if (lesson.room != null) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Место', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _InfoTable(items: [
                  _InfoRow('Кабинет', lesson.room?.roomName),
                  _InfoRow('Этаж', lesson.room?.floor?.toString()),
                  _InfoRow('Блок', lesson.room?.block),
                ]),
              ]),
            ),
          ),
        ],
        if ((lesson.topic?.name ?? '').trim().isNotEmpty ||
            (lesson.task?.name ?? '').trim().isNotEmpty ||
            (lesson.lastTask?.name ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Материалы', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if ((lesson.topic?.name ?? '').trim().isNotEmpty) _RichBlock(title: 'Тема', text: lesson.topic!.name!),
                if ((lesson.task?.name ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RichBlock(title: 'Домашнее задание', text: lesson.task!.name!),
                ],
                if ((lesson.lastTask?.name ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RichBlock(title: 'Предыдущее задание', text: lesson.lastTask!.name!),
                ],
              ]),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Оценки и посещаемость', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (lesson.marks.isEmpty)
                Text('Нет оценок/пометок', style: TextStyle(color: cs.onSurfaceVariant))
              else
                Column(
                  children: lesson.marks
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DetailedMarkTile(mark: m),
                          ))
                      .toList(),
                ),
            ]),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Урок'),
        actions: [
          IconButton(
            tooltip: 'Копировать всё',
            onPressed: () => Copy.text(context, _lessonToCopyText(lesson), label: 'Урок'),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: isWide(context) ? AppScaffoldMaxWidth(maxWidth: 980, child: page) : page,
    );
  }

  String _lessonToCopyText(Lesson l) {
    final subject = l.subject?.nameRu ?? l.subject?.name ?? '';
    final teacher = l.teacher?.fio ?? '';
    final room = l.room?.roomName ?? '';
    final time = (l.startTime != null && l.endTime != null) ? '${l.startTime}–${l.endTime}' : '';
    final date = l.lessonDay != null ? DateFormat('d MMMM yyyy').format(l.lessonDay!.toLocal()) : '';
    final marks = l.marks.isNotEmpty ? l.marks.map(MarkUi.label).join(', ') : '';

    return [
      'Предмет: $subject',
      if (date.isNotEmpty) 'Дата: $date',
      if (time.isNotEmpty) 'Время: $time',
      if (teacher.isNotEmpty) 'Учитель: $teacher',
      if (room.isNotEmpty) 'Кабинет: $room',
      if ((l.topic?.name ?? '').trim().isNotEmpty) 'Тема: ${l.topic!.name}',
      if ((l.task?.name ?? '').trim().isNotEmpty) 'ДЗ: ${l.task!.name}',
      if (marks.isNotEmpty) 'Оценки/отметки: $marks',
      if (l.uid != null) 'UID: ${l.uid}',
      if (l.scheduleItemId != null) 'ScheduleItemId: ${l.scheduleItemId}',
    ].join('\n');
  }
}

class _DetailedMarkTile extends StatelessWidget {
  final Mark mark;
  const _DetailedMarkTile({required this.mark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final label = MarkUi.label(mark);
    final colors = MarkUi.colors(context, mark);
    final bg = colors.bg.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(color: colors.fg, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Тип: ${MarkUi.typeTitle(mark)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((mark.createdAt ?? mark.updatedAt) != null)
                Text(
                  'Дата: ${DateFormat('d MMM yyyy, HH:mm').format((mark.createdAt ?? mark.updatedAt)!.toLocal())}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (mark.markType != null) _Chip(label: 'MarkType', value: mark.markType!),
            if (mark.absent == true) const _InfoPill(icon: Icons.report_rounded, text: 'Отсутствие'),
            if (mark.absentType != null && mark.absentType!.trim().isNotEmpty) _Chip(label: 'AbsentType', value: mark.absentType!),
            if (mark.lateMinutes != null && mark.lateMinutes! > 0) _Chip(label: 'Опоздание', value: '${mark.lateMinutes} мин'),
            if (mark.absentReason != null && mark.absentReason!.trim().isNotEmpty) _Chip(label: 'Причина', value: mark.absentReason!),
          ],
        ),
        if (mark.note != null && mark.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Комментарий: ${mark.note}', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

class TeacherDetailsScreen extends StatelessWidget {
  final LessonTeacher teacher;
  const TeacherDetailsScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final page = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(teacher.fio.isNotEmpty ? teacher.fio : 'Учитель'),
            subtitle: Text([if (teacher.pinAsString != null) 'ПИН: ${teacher.pinAsString}', if (teacher.pin != null) '(${teacher.pin})'].join(' ')),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Детали', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _InfoTable(items: [
                _InfoRow('Фамилия', teacher.lastName),
                _InfoRow('Имя', teacher.firstName),
                _InfoRow('Отчество', teacher.midName),
                _InfoRow('ПИН', teacher.pin?.toString()),
              ]),
            ]),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Учитель'),
        actions: [
          IconButton(
            tooltip: 'Копировать всё',
            onPressed: () {
              final text = [
                'ФИО: ${teacher.fio}',
                if (teacher.pinAsString != null) 'ПИН: ${teacher.pinAsString}',
                if (teacher.pin != null) 'PIN (число): ${teacher.pin}',
              ].join('\n');
              Copy.text(context, text, label: 'Учитель');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: isWide(context) ? AppScaffoldMaxWidth(maxWidth: 980, child: page) : page,
    );
  }
}

class _RichBlock extends StatelessWidget {
  final String title;
  final String text;
  const _RichBlock({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        SelectableText(text),
      ]),
    );
  }
}

/// ----------------------------------------------------------------------
/// SETTINGS SHEET
/// ----------------------------------------------------------------------
class SettingsSheet extends StatefulWidget {
  final AppSettingsStore settings;
  final AppLockStore appLock;

  const SettingsSheet({super.key, required this.settings, required this.appLock});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late ThemeMode _mode;
  late TextEditingController _baseUrl;
  late TextEditingController _ua;

  bool _lockEnabled = false;
  int _lockTimeout = 60;

  @override
  void initState() {
    super.initState();
    _mode = widget.settings.themeMode;
    _baseUrl = TextEditingController(text: widget.settings.baseUrl);
    _ua = TextEditingController(text: widget.settings.userAgent);
    _lockEnabled = widget.appLock.enabled;
    _lockTimeout = widget.appLock.timeoutSec;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _ua.dispose();
    super.dispose();
  }

  Future<void> _setAppPasscode() async {
    final res = await showDialog<String>(
      context: context,
      builder: (_) => const _SetPasscodeDialog(),
    );
    if (!mounted) return;
    if (res == null) return;
    await widget.appLock.setPasscode(res);
    setState(() => _lockEnabled = widget.appLock.enabled);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(
                leading: Icon(Icons.tune_rounded),
                title: Text('Настройки'),
                subtitle: Text('Тема, User-Agent, адрес API и блокировка'),
              ),
              const SizedBox(height: 6),

              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.palette_rounded),
                          SizedBox(width: 10),
                          Text('Тема', style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('Светлая'), icon: Icon(Icons.light_mode_rounded)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная'), icon: Icon(Icons.dark_mode_rounded)),
                          ButtonSegment(value: ThemeMode.system, label: Text('Системная'), icon: Icon(Icons.settings_suggest_rounded)),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) async {
                          final v = s.first;
                          setState(() => _mode = v);
                          await widget.settings.setThemeMode(v);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_rounded),
                          SizedBox(width: 10),
                          Text('Пароль на вход в приложение', style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: _lockEnabled,
                        onChanged: (v) async {
                          if (!widget.appLock.hasPasscode && v) {
                            await _setAppPasscode();
                            if (!mounted) return;
                            setState(() => _lockEnabled = widget.appLock.enabled);
                            return;
                          }
                          await widget.appLock.setEnabled(v);
                          setState(() => _lockEnabled = v);
                        },
                        title: const Text('Включить блокировку'),
                        subtitle: Text(widget.appLock.hasPasscode ? 'Пароль задан' : 'Пароль не задан'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _lockEnabled ? _setAppPasscode : null,
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Изменить пароль'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.appLock.hasPasscode
                                  ? () async {
                                      await widget.appLock.clearPasscode();
                                      if (!mounted) return;
                                      setState(() {
                                        _lockEnabled = widget.appLock.enabled;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Удалить пароль'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Таймаут блокировки:', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _lockTimeout,
                            underline: const SizedBox.shrink(),
                            items: const [0, 15, 30, 60, 120, 300, 600]
                                .map((s) => DropdownMenuItem(value: s, child: Text(s == 0 ? 'сразу' : '${s}s')))
                                .toList(),
                            onChanged: !_lockEnabled
                                ? null
                                : (v) async {
                                    if (v == null) return;
                                    setState(() => _lockTimeout = v);
                                    await widget.appLock.setTimeoutSec(v);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.public_rounded),
                          SizedBox(width: 10),
                          Text('Сеть', style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ua,
                        decoration: const InputDecoration(labelText: 'User-Agent', prefixIcon: Icon(Icons.public_rounded)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _ua.text = AppSettingsStore.kDefaultUserAgent);
                              },
                              child: const Text('Сбросить User-Agent'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _baseUrl,
                        decoration: const InputDecoration(
                          labelText: 'Base URL API',
                          hintText: 'https://kundoluk.edu.gov.kg/api/',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _baseUrl.text = AppSettingsStore.kDefaultBaseUrl);
                              },
                              child: const Text('Сбросить Base URL'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () async {
                    await widget.settings.setUserAgent(_ua.text.trim());
                    await widget.settings.setBaseUrl(_baseUrl.text.trim());
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SetPasscodeDialog extends StatefulWidget {
  const _SetPasscodeDialog();

  @override
  State<_SetPasscodeDialog> createState() => _SetPasscodeDialogState();
}

class _SetPasscodeDialogState extends State<_SetPasscodeDialog> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  void _ok() {
    final a = _p1.text.trim();
    final b = _p2.text.trim();
    if (a.isEmpty || b.isEmpty) {
      setState(() => _error = 'Заполни оба поля');
      return;
    }
    if (a.length < 4) {
      setState(() => _error = 'Минимум 4 символа');
      return;
    }
    if (a != b) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Задать пароль приложения'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _p1,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Пароль / PIN',
                prefixIcon: const Icon(Icons.password_rounded),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _p2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Повтори', prefixIcon: Icon(Icons.password_rounded)),
              onSubmitted: (_) => _ok(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _ok, child: const Text('Сохранить')),
      ],
    );
  }
}

/// ----------------------------------------------------------------------
/// MARK UI helpers
/// ----------------------------------------------------------------------
class MarkUiColors {
  final Color bg;
  final Color fg;
  MarkUiColors(this.bg, this.fg);
}

class MarkUi {
  static String label(Mark m) {
    if (m.value != null && m.value != 0) return m.value.toString();
    if (m.customMark != null && m.customMark!.trim().isNotEmpty) return m.customMark!;
    if (m.absent == true) return 'Н';
    if ((m.lateMinutes ?? 0) > 0) return 'ОП';
    return '—';
  }

  static String typeTitle(Mark m) {
    final t = (m.markType ?? '').trim();
    if (t.isEmpty) {
      if (m.absent == true) return 'Отсутствие';
      if ((m.lateMinutes ?? 0) > 0) return 'Опоздание';
      return 'Запись';
    }
    return switch (t) {
      'general' => 'Оценка',
      'control' => 'Контрольная',
      'homework' => 'Домашняя работа',
      'test' => 'Тест',
      'laboratory' => 'Лабораторная',
      'write' => 'Письменная',
      'practice' => 'Практическая',
      _ => 'Тип: $t',
    };
  }

  static MarkUiColors colors(BuildContext context, Mark m) {
    final cs = Theme.of(context).colorScheme;
    final l = label(m).toLowerCase();

    final isBad = (l == '2' || l == '1');
    final isAbsent = (l == 'н' || m.absent == true);
    final isLate = (l == 'оп' || (m.lateMinutes ?? 0) > 0);

    if (isAbsent) return MarkUiColors(cs.errorContainer, cs.onErrorContainer);
    if (isLate) return MarkUiColors(cs.tertiaryContainer, cs.onTertiaryContainer);
    if (isBad) return MarkUiColors(cs.errorContainer, cs.onErrorContainer);
    if (m.isNumericMark) return MarkUiColors(cs.secondaryContainer, cs.onSecondaryContainer);

    return MarkUiColors(cs.surfaceContainerHighest, cs.onSurface);
  }

  static String tooltip(MarkEntry e) {
    final parts = <String>[];
    parts.add('Предмет: ${e.subjectName}');
    if (e.teacherName != null && e.teacherName!.trim().isNotEmpty) parts.add('Учитель: ${e.teacherName}');
    parts.add('Тип: ${typeTitle(e.mark)}');
    parts.add('Значение: ${label(e.mark)}');
    parts.add('Дата урока: ${DateFormat('d MMM yyyy').format(e.lessonDate)}');
    if (e.lessonTime != null) parts.add('Время урока: ${e.lessonTime}');
    final t = e.markCreated?.toLocal();
    if (t != null) parts.add('Выставлено: ${DateFormat('d MMM yyyy, HH:mm').format(t)}');
    if (e.mark.absent == true) {
      parts.add('Отсутствие: да');
      if (e.mark.absentType != null && e.mark.absentType!.trim().isNotEmpty) parts.add('AbsentType: ${e.mark.absentType}');
      if ((e.mark.lateMinutes ?? 0) > 0) parts.add('Опоздание: ${e.mark.lateMinutes} мин');
      if (e.mark.absentReason != null && e.mark.absentReason!.trim().isNotEmpty) parts.add('Причина: ${e.mark.absentReason}');
    }
    if (e.mark.note != null && e.mark.note!.trim().isNotEmpty) parts.add('Комментарий: ${e.mark.note}');
    return parts.join('\n');
  }
}

class MarkStats {
  final int total;
  final int numericCount;
  final int notesCount;
  final double? avg;

  MarkStats({required this.total, required this.numericCount, required this.notesCount, required this.avg});

  static MarkStats ofEntries(List<MarkEntry> entries) {
    final total = entries.length;
    int numeric = 0;
    int notes = 0;
    int sum = 0;

    for (final e in entries) {
      final m = e.mark;
      if (m.isNumericMark) {
        numeric++;
        sum += m.value!;
      } else {
        notes++;
      }
    }

    final avg = numeric == 0 ? null : (sum / numeric);
    return MarkStats(total: total, numericCount: numeric, notesCount: notes, avg: avg);
  }
}
