import 'package:flutter/material.dart';

import '../data/api/kundoluk_api.dart';
import '../data/stores/app_lock_store.dart';
import '../data/stores/app_settings_store.dart';
import '../data/stores/auth_store.dart';
import '../ui/screens/app_lock/app_lock_screen.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/home/home_screen.dart';

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
    WidgetsBinding.instance.addObserver(this); // <-- совместимее
    _locked = widget.appLock.enabled && widget.appLock.hasPasscode;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // <-- совместимее
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

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
