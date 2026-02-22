import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/kundoluk_api.dart';
import '../data/stores/app_lock_store.dart';
import '../data/stores/app_settings_store.dart';
import '../data/stores/auth_store.dart';

class AppDependencies {
  final SharedPreferences prefs;
  final AppSettingsStore settings;
  final AuthStore auth;
  final AppLockStore appLock;
  final KundolukApi api;

  AppDependencies({
    required this.prefs,
    required this.settings,
    required this.auth,
    required this.appLock,
    required this.api,
  });
}

abstract class AppDI {
  static Future<AppDependencies> build() async {
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

    return AppDependencies(
      prefs: prefs,
      settings: settings,
      auth: auth,
      appLock: appLock,
      api: api,
    );
  }
}
