import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/school_year/school_year.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import 'compact_lesson_card.dart';
import 'date_chip.dart';
import 'lesson_details_screen.dart';
import 'today_bloc.dart';

class TodayScreen extends StatelessWidget {
  final KundolukApi api;
  final AuthStore auth;

  const TodayScreen({super.key, required this.api, required this.auth});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TodayBloc(api: api, auth: auth)..add(TodayStarted()),
      child: const _TodayView(),
    );
  }
}

class _TodayView extends StatefulWidget {
  const _TodayView();

  @override
  State<_TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<_TodayView> {
  static const double _chipW = 80;
  static const double _chipPad = 8;
  static const double _itemExtent = _chipW + _chipPad;

  final ScrollController _datesCtrl = ScrollController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selected = context.read<TodayBloc>().state.selectedDate;
      _centerDateInRibbon(selected);
    });

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _datesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateFromCalendar(
    BuildContext context,
    DateTime selected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      locale: const Locale('ru', 'RU'),
      helpText: 'Выбери дату',
      confirmText: 'ОК',
      cancelText: 'Отмена',
    );

    if (!context.mounted || picked == null) return;
    context.read<TodayBloc>().add(
      TodayDateSelected(DateTime(picked.year, picked.month, picked.day)),
    );
  }

  int _indexOfDate(List<DateTime> dateList, DateTime date) =>
      dateList.indexWhere((d) => d.isSameDate(date));

  void _centerDateInRibbon(DateTime date) {
    if (!_datesCtrl.hasClients) return;
    final dateList = context.read<TodayBloc>().state.dateList;
    final idx = _indexOfDate(dateList, date);
    if (idx < 0) return;
    final viewport = _datesCtrl.position.viewportDimension;
    final target = idx * _itemExtent - (viewport / 2) + (_itemExtent / 2);
    final maxExtent = _datesCtrl.position.maxScrollExtent;
    _datesCtrl.jumpTo(target.clamp(0.0, maxExtent));
  }

  void _animateCenterDate(List<DateTime> dateList, DateTime date) {
    if (!_datesCtrl.hasClients) return;
    final idx = _indexOfDate(dateList, date);
    if (idx < 0) return;
    final viewport = _datesCtrl.position.viewportDimension;
    final target = idx * _itemExtent - (viewport / 2) + (_itemExtent / 2);
    final maxExtent = _datesCtrl.position.maxScrollExtent;
    _datesCtrl.animateTo(
      target.clamp(0.0, maxExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TodayBloc, TodayState>(
      listenWhen: (prev, curr) =>
          prev.selectedDate != curr.selectedDate ||
          prev.ribbonJumpVersion != curr.ribbonJumpVersion ||
          prev.shouldNotifySundayAutoMove != curr.shouldNotifySundayAutoMove ||
          prev.shouldNotifySundayBlocked != curr.shouldNotifySundayBlocked,
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _animateCenterDate(state.dateList, state.selectedDate),
        );

        if (state.shouldNotifySundayAutoMove) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сегодня воскресенье, показан понедельник'),
            ),
          );
        }
        if (state.shouldNotifySundayBlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Воскресенье - выходной, выбери другой день'),
            ),
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<TodayBloc>();
        final cs = Theme.of(context).colorScheme;

        final dataState = state.dataState;
        final schedule = dataState.cache;
        final quarter = SchoolYear.getQuarter(state.selectedDate, nearest: false);
        final quarterProgress = SchoolYear.getQuarterProgress(state.selectedDate);

        final showOfflineBanner =
            dataState.status == UiNetStatus.offlineUsingCache;
        final offlineReason = dataState.error;
        final offlineSubtitle = offlineReason == null
            ? 'Показаны сохраненные данные.'
            : TodayBloc.isConnectivityish(offlineReason)
            ? 'Нет сети или сервер недоступен. Показаны сохраненные данные.'
            : 'Сервер вернул ошибку. Показаны сохраненные данные.';

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              snap: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              titleSpacing: 16,
              title: Text(
                state.selectedDate.russianTextDateWithWeekday,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Сегодня',
                  onPressed: () => bloc.add(TodayJumpToTodayRequested()),
                  icon: const Icon(Icons.today_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Выбрать дату',
                  onPressed: () =>
                      _pickDateFromCalendar(context, state.selectedDate),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: () => bloc.add(TodayRefreshRequested()),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(62),
                child: Column(
                  children: [
                    SizedBox(
                      height: 58,
                      child: ListView.builder(
                        key: const PageStorageKey<String>('dates_list'),
                        controller: _datesCtrl,
                        scrollDirection: Axis.horizontal,
                        itemCount: state.dateList.length,
                        itemBuilder: (_, i) {
                          final date = state.dateList[i];
                          final isToday = date.isSameDate(state.effectiveToday);
                          final isSelected = date.isSameDate(
                            state.selectedDate,
                          );
                          final isVacation = SchoolYear.isVacation(date);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: DateChip(
                              date: date,
                              isToday: isToday,
                              isSelected: isSelected,
                              isVacation: isVacation,
                              onTap: () {
                                if (isSelected) return;
                                bloc.add(TodayDateSelected(date));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (dataState.status == UiNetStatus.loading)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      Container(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                  ],
                ),
              ),
            ),
            if (showOfflineBanner)
              SliverToBoxAdapter(
                child: OfflineBanner(
                  title: 'Офлайн',
                  subtitle: offlineSubtitle,
                  onRetry: () => bloc.add(TodayRefreshRequested()),
                ),
              ),
            if (quarter != null && quarterProgress != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _QuarterProgressCard(
                    quarter: quarter,
                    progress: quarterProgress,
                    isVacation: SchoolYear.isVacation(state.selectedDate),
                  ),
                ),
              ),
            if (dataState.status == UiNetStatus.errorNoCache &&
                schedule == null)
              SliverFillRemaining(
                child: ApiErrorView(
                  failure:
                      dataState.error ??
                      ApiFailure(
                        kind: ApiErrorKind.unknown,
                        title: 'Ошибка',
                        message: 'Не удалось загрузить данные',
                      ),
                  onRetry: () => bloc.add(TodayRefreshRequested()),
                  vacationHint: SchoolYear.isVacation(state.selectedDate),
                ),
              )
            else if (schedule == null &&
                dataState.status != UiNetStatus.loading)
              SliverFillRemaining(
                child: EmptyView(
                  title: 'Нет данных',
                  subtitle: SchoolYear.isVacation(state.selectedDate)
                      ? 'Сейчас каникулы.'
                      : 'На этот день расписание пустое или еще не загружено.',
                  onRetry: () => bloc.add(TodayRefreshRequested()),
                ),
              )
            else if (schedule != null && schedule.lessons.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  title: 'Уроков нет',
                  subtitle: SchoolYear.isVacation(state.selectedDate)
                      ? 'Сейчас каникулы.'
                      : 'На этот день расписание пустое.',
                  onRetry: () => bloc.add(TodayRefreshRequested()),
                ),
              )
            else if (schedule != null)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final lesson = schedule.lessons[i];
                  final now = DateTime.now();
                  final isCurrent = _isCurrentLesson(
                    lesson,
                    now,
                    state.selectedDate,
                  );
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LessonDetailsScreen(lesson: lesson, api: bloc.api),
                      ),
                    ),
                    child: CompactLessonCard(
                      lesson: lesson,
                      isCurrent: isCurrent,
                    ),
                  );
                }, childCount: schedule.lessons.length),
              ),
          ],
        );
      },
    );
  }

  bool _isCurrentLesson(Lesson lesson, DateTime now, DateTime selectedDay) {
    if (!selectedDay.isSameDate(now)) return false;
    final start = _parseTime(selectedDay, lesson.startTime);
    final end = _parseTime(selectedDay, lesson.endTime);
    if (start == null || end == null) return false;
    return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
        (now.isBefore(end) || now.isAtSameMomentAs(end));
  }

  DateTime? _parseTime(DateTime day, String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }
}

class _QuarterProgressCard extends StatelessWidget {
  final int quarter;
  final double progress;
  final bool isVacation;

  const _QuarterProgressCard({
    required this.quarter,
    required this.progress,
    required this.isVacation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalized = progress.clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Четверть завершена на ${normalized.round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$quarter',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized / 100,
              minHeight: 10,
            ),
          ),
          if (isVacation) ...[
            const SizedBox(height: 8),
            Text(
              'На выбранную дату идут каникулы.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
