import 'package:flutter/material.dart';

import '../../../data/stores/app_lock_store.dart';
import '../../../data/stores/app_settings_store.dart';
import 'set_passcode_dialog.dart';

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
      builder: (_) => const SetPasscodeDialog(),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Светлая'),
                              icon: Icon(Icons.light_mode_rounded),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Тёмная'),
                              icon: Icon(Icons.dark_mode_rounded),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Системная'),
                              icon: Icon(Icons.settings_suggest_rounded),
                            ),
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
                                        setState(() => _lockEnabled = widget.appLock.enabled);
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
                          decoration: const InputDecoration(
                            labelText: 'User-Agent',
                            prefixIcon: Icon(Icons.public_rounded),
                          ),
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
                            hintText: 'Оставь пустым, чтобы использовать стандартный',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _baseUrl.text = widget.settings.defaultBaseUrl);
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
