import 'package:flutter/material.dart';

import '../../../data/stores/app_lock_store.dart';
import '../../widgets/app_scaffold_max_width.dart';

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
