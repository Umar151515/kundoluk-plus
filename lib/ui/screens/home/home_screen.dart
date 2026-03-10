import 'package:flutter/material.dart';

import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/app_lock_store.dart';
import '../../../data/stores/app_settings_store.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/user_role.dart';
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
      builder: (_) => AccountsSheet(
        api: widget.api,
        auth: widget.auth,
        settings: widget.settings,
      ),
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
      builder: (_) =>
          SettingsSheet(settings: widget.settings, appLock: widget.appLock),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.activeAccount?.accountJson != null
        ? Account.fromJson(widget.auth.activeAccount!.accountJson!)
        : null;
    final role = account?.userRole ?? UserRole.student;
    final roleConfig = RoleHomeConfig.forRole(role);
    final selectedTab = roleConfig.tabs.contains(_tab)
        ? _tab
        : roleConfig.tabs.first;
    final tabTitle = roleConfig.titleByTab[selectedTab] ?? 'Профиль';
    final displayName = account?.fio.isNotEmpty == true
        ? account!.fio
        : widget.auth.activeAccount?.username;
    final classLabel = account?.classLabel;

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tabTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if ((classLabel ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Класс: $classLabel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if ((displayName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  displayName!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        toolbarHeight: 84,
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
          duration: const Duration(milliseconds: 220),
          child: _buildTabScreen(selectedTab),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: roleConfig.tabs.indexOf(selectedTab),
        onDestinationSelected: (i) => setState(() => _tab = roleConfig.tabs[i]),
        destinations: roleConfig.tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(roleConfig.iconByTab[tab] ?? Icons.circle),
                label: roleConfig.labelByTab[tab] ?? '',
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTabScreen(HomeTab tab) {
    return switch (tab) {
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
    };
  }
}

class RoleHomeConfig {
  final List<HomeTab> tabs;
  final Map<HomeTab, String> labelByTab;
  final Map<HomeTab, String> titleByTab;
  final Map<HomeTab, IconData> iconByTab;

  const RoleHomeConfig({
    required this.tabs,
    required this.labelByTab,
    required this.titleByTab,
    required this.iconByTab,
  });

  static RoleHomeConfig forRole(UserRole role) {
    return switch (role) {
      UserRole.student => _student(),
      UserRole.teacher => _teacher(),
      UserRole.parent => _parent(),
      UserRole.admin => _admin(),
      UserRole.unknown => _student(),
    };
  }

  static RoleHomeConfig _student() {
    const tabs = [
      HomeTab.today,
      HomeTab.marks,
      HomeTab.quarterMarks,
      HomeTab.profile,
    ];
    return const RoleHomeConfig(
      tabs: tabs,
      labelByTab: {
        HomeTab.today: 'Сегодня',
        HomeTab.marks: 'Оценки',
        HomeTab.quarterMarks: 'Итоги',
        HomeTab.profile: 'Профиль',
      },
      titleByTab: {
        HomeTab.today: 'Расписание',
        HomeTab.marks: 'Оценки',
        HomeTab.quarterMarks: 'Итоги',
        HomeTab.profile: 'Профиль',
      },
      iconByTab: {
        HomeTab.today: Icons.today_rounded,
        HomeTab.marks: Icons.grade_rounded,
        HomeTab.quarterMarks: Icons.emoji_events_rounded,
        HomeTab.profile: Icons.person_rounded,
      },
    );
  }

  static RoleHomeConfig _teacher() {
    return _student();
  }

  static RoleHomeConfig _parent() {
    return _student();
  }

  static RoleHomeConfig _admin() {
    return _student();
  }
}
