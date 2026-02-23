import 'package:flutter/material.dart';

import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/app_lock_store.dart';
import '../../../data/stores/app_settings_store.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/account.dart';
import '../auth/accounts_sheet.dart';
import '../marks/marks_screen.dart';
import '../profile/profile_screen.dart';
import '../quarter_marks/quarter_marks_screen.dart';
import '../settings/settings_sheet.dart';
import '../today/today_screen.dart';

enum HomeTab { today, marks, quarterMarks, profile }

class HomeScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  final AppSettingsStore settings;
  final AppLockStore appLock;

  const HomeScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.appLock,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.today;
  late final VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _authListener = () {
      if (mounted) setState(() {});
    };
    widget.auth.addListener(_authListener);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _openAccounts() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AccountsSheet(api: widget.api, auth: widget.auth, settings: widget.settings),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SettingsSheet(settings: widget.settings, appLock: widget.appLock),
    );
    if (!mounted) return;
    setState(() {});
  }

  String _getTabTitle() {
    return switch (_tab) {
      HomeTab.today => 'Расписание',
      HomeTab.marks => 'Оценки',
      HomeTab.quarterMarks => 'Итоги',
      HomeTab.profile => 'Профиль',
    };
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.activeAccount?.accountJson != null
        ? Account.fromJson(widget.auth.activeAccount!.accountJson!)
        : null;

    final tabTitle = _getTabTitle();
    final displayName = account?.fio.isNotEmpty == true ? account!.fio : widget.auth.activeAccount?.username;
    final classLabel = account?.classLabel;

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tabTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (classLabel != null && classLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Класс: $classLabel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (displayName != null && displayName.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        toolbarHeight: 80,
        actions: [
          IconButton(
            tooltip: 'Аккаунты',
            onPressed: _openAccounts,
            icon: const Icon(Icons.switch_account_rounded),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_tab) {
            HomeTab.today => TodayScreen(
                key: ValueKey('today_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
              ),
            HomeTab.marks => MarksScreen(
                key: ValueKey('marks_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
              ),
            HomeTab.quarterMarks => QuarterMarksScreen(
                key: ValueKey('qm_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
              ),
            HomeTab.profile => ProfileScreen(
                key: ValueKey('profile_${widget.auth.activeAccount?.id}'),
                api: widget.api,
                auth: widget.auth,
                appLock: widget.appLock,
              ),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = HomeTab.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Сегодня'),
          NavigationDestination(icon: Icon(Icons.grade_rounded), label: 'Оценки'),
          NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Итоги'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }
}
