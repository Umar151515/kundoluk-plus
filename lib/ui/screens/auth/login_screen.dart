import 'package:flutter/material.dart';

import '../../../core/helpers/copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/app_lock_store.dart';
import '../../../data/stores/app_settings_store.dart';
import '../../../data/stores/auth_store.dart';
import '../../widgets/app_scaffold_max_width.dart';
import '../../widgets/error_card.dart';
import '../home/home_screen.dart';
import '../settings/settings_sheet.dart';
import 'accounts_sheet.dart';

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
          builder: (_) => HomeScreen(
            api: widget.api,
            auth: widget.auth,
            settings: widget.settings,
            appLock: widget.appLock,
          ),
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
