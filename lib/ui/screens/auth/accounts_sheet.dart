import 'package:flutter/material.dart';

import '../../../core/helpers/copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/account_info.dart';
import '../../../data/stores/auth_store.dart';
import '../../../data/stores/app_settings_store.dart';
import '../../../domain/models/account.dart';
import '../../widgets/error_card.dart';
import 'add_account_dialog.dart';

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
    final res = await showDialog<LoginDialogResult>(
      context: context,
      builder: (_) => const AddAccountDialog(),
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
                    child: Text(
                      'Аккаунты',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
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
                ErrorCard(
                  failure: _failure!,
                  onCopy: () => Copy.text(context, _failure.toString(), label: 'Ошибка'),
                ),
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
