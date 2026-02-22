import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/helpers/layout.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/app_lock_store.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/account.dart';
import '../../widgets/chips.dart';
import '../../widgets/info_table.dart';
import '../auth/accounts_sheet.dart';
import '../auth/login_screen.dart';
import 'change_password_sheet.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account?.fio.isNotEmpty == true ? account!.fio : 'Ученик',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (account != null) AppChip(label: 'Класс', value: account.classLabel),
                          if (auth.activeAccount?.username != null) AppChip(label: 'Логин', value: auth.activeAccount!.username),
                          if (account?.pinAsString != null) AppChip(label: 'ПИН', value: account!.pinAsString!),
                        ],
                      ),
                      if (account?.school?.nameRu != null) ...[
                        const SizedBox(height: 8),
                        Text(account!.school!.nameRu!, style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Токен очищен. Нужно войти заново.')),
                  );
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
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(
                        api: api,
                        auth: auth,
                        settings: api.settings,
                        appLock: appLock,
                      ),
                    ),
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
                  InfoTable(
                    items: [
                      InfoRow('User ID', account.userId),
                      InfoRow('Student ID', account.studentId),
                      InfoRow('ОКПО', account.okpo ?? account.school?.okpo),
                      InfoRow('Роль', account.role),
                      InfoRow('Язык', account.locale),
                      InfoRow('Email', account.email),
                      InfoRow('Телефон', account.phone),
                      InfoRow(
                        'Дата рождения',
                        account.birthdate != null ? DateFormat('d MMMM yyyy').format(account.birthdate!.toLocal()) : null,
                      ),
                      InfoRow('Требует смены пароля', account.changePassword?.toString()),
                      InfoRow('Соглашение подписано', account.isAgreementSigned?.toString()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return isWide(context) ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: content)) : content;
  }
}
