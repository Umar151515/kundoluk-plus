import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsStore extends ChangeNotifier {
  final SharedPreferences prefs;
  AppSettingsStore(this.prefs);

  static const String _kThemeMode = 'theme_mode';
  static const String _kBaseUrl = 'base_url';
  static const String _kUserAgent = 'user_agent';

  static const String kDefaultBaseUrlMobile = 'https://kundoluk.edu.gov.kg/api/';
  static const String kDefaultBaseUrlWeb = 'https://cors-anywhere.herokuapp.com/https://kundoluk.edu.gov.kg/api/';
  static const String kDefaultUserAgent = 'Dart/3.9 (dart:io)';

  ThemeMode themeMode = ThemeMode.system;
  String baseUrl = kDefaultBaseUrlMobile;
  String userAgent = kDefaultUserAgent;

  String get defaultBaseUrl => kIsWeb ? kDefaultBaseUrlWeb : kDefaultBaseUrlMobile;

  bool get isDefaultBaseUrl {
    final normalized = baseUrl.trim();
    return normalized == defaultBaseUrl || normalized == (defaultBaseUrl.endsWith('/') ? defaultBaseUrl : '$defaultBaseUrl/');
  }

  bool get shouldShowWebCorsHint => kIsWeb && isDefaultBaseUrl;

  Future<void> load() async {
    final tm = prefs.getString(_kThemeMode) ?? 'system';
    themeMode = switch (tm) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final saved = prefs.getString(_kBaseUrl);
    baseUrl = (saved == null || saved.trim().isEmpty) ? defaultBaseUrl : saved.trim();
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
    final fixed = url.trim().isEmpty ? defaultBaseUrl : url.trim();
    baseUrl = fixed.endsWith('/') ? fixed : '$fixed/';
    await prefs.setString(_kBaseUrl, baseUrl);
    notifyListeners();
  }

  Future<void> resetBaseUrl() => setBaseUrl(defaultBaseUrl);

  Future<void> setUserAgent(String ua) async {
    userAgent = ua.trim().isEmpty ? kDefaultUserAgent : ua.trim();
    await prefs.setString(_kUserAgent, userAgent);
    notifyListeners();
  }

  Future<void> resetUserAgent() => setUserAgent(kDefaultUserAgent);
}
