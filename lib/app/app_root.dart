import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/api/kundoluk_api.dart';
import '../data/stores/app_lock_store.dart';
import '../data/stores/app_settings_store.dart';
import '../data/stores/auth_store.dart';
import 'app_gate.dart';

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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
