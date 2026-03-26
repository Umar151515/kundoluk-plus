import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/stores/app_lock_store.dart';
import '../../widgets/app_scaffold_max_width.dart';
import '../../widgets/pin_pad.dart';

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
  bool _biometricAvailable = false;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final available = await widget.appLock.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available && widget.appLock.biometricEnabled) {
      await _tryBiometric(auto: true);
    }
  }

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

  void _appendDigit(String digit) {
    if (_ctrl.text.length >= 8) return;
    setState(() {
      _bad = false;
      _ctrl.text += digit;
    });
  }

  void _backspace() {
    if (_ctrl.text.isEmpty) return;
    setState(() {
      _bad = false;
      _ctrl.text = _ctrl.text.substring(0, _ctrl.text.length - 1);
    });
  }

  Future<void> _tryBiometric({bool auto = false}) async {
    if (_authInProgress) return;
    setState(() => _authInProgress = true);
    String? errorMessage;
    bool ok = false;
    try {
      ok = await widget.appLock.authenticateWithBiometrics();
    } on PlatformException catch (err) {
      errorMessage = err.message;
    } finally {
      if (!mounted) return;
      setState(() => _authInProgress = false);
    }
    if (ok) {
      widget.onUnlocked();
      return;
    }
    if (!auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'Не удалось подтвердить вход по биометрии',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final useBiometric = _biometricAvailable && widget.appLock.biometricEnabled;

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      readOnly: true,
                      enableInteractiveSelection: false,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'PIN-код',
                        errorText: _bad ? 'Неверный PIN-код' : null,
                        prefixIcon: const Icon(Icons.pin_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (useBiometric) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _authInProgress ? null : () => _tryBiometric(),
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(_authInProgress ? 'Проверка...' : 'Войти по биометрии'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Если биометрия недоступна, используй PIN-код приложения.',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _tryUnlock,
                        child: const Text('Разблокировать'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PinPad(
                      value: _ctrl.text,
                      onDigit: _appendDigit,
                      onBackspace: _backspace,
                      actionIcon: Icons.lock_open_rounded,
                      onAction: _tryUnlock,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
