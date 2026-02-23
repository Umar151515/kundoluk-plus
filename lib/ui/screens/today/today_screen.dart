import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/screen_data_state.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/daily_schedule.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/school_year/school_year.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import 'compact_lesson_card.dart';
import 'date_chip.dart';
import 'lesson_details_screen.dart';

class TodayScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const TodayScreen({super.key, required this.api, required this.auth});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selected;
  late DateTime _today;

  ScreenDataState<DailySchedule?> _state = ScreenDataState.initial<DailySchedule?>(null);

  static const int _totalDays = 178;
  late final List<DateTime> _dateList;
  static const double _chipW = 80;
  static const double _chipPad = 8;
  static const double _itemExtent = _chipW + _chipPad;

  final ScrollController _datesCtrl = ScrollController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    if (_today.weekday == DateTime.sunday) {
      _selected = _today.add(const Duration(days: 1));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сегодня воскресенье — показан понедельник')),
        );
      });
    } else {
      _selected = _today;
    }

    _dateList = _generateDateList(_today);

    WidgetsBinding.instance.addPostFrameCallback((_) => _centerDateInRibbon(_selected));

    _bootstrap();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _datesCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadFromCache();
    unawaited(_fetchFromNetwork());
  }

  bool _isConnectivityish(ApiFailure? f) {
    final k = f?.kind;
    return k == ApiErrorKind.network || k == ApiErrorKind.timeout || k == ApiErrorKind.badUrl;
  }

  Future<void> _loadFromCache() async {
    final key = CacheKeys.schedule(_selected);
    final json = await widget.auth.loadFromCache(key);

    DailySchedule? parsed;
    if (json != null) {
      try {
        final action = json.containsKey('actionResult') ? json['actionResult'] : json;
        final list = (action as List?) ?? const [];
        final lessons = list
            .map((e) => Lesson.fromJson(e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}))
            .whereType<Lesson>()
            .toList()
          ..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
        parsed = DailySchedule(date: _selected.dateOnly, lessons: lessons);
      } catch (_) {
        parsed = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(cache: parsed, status: _state.status, error: _state.error);
    });
  }

  Future<void> _fetchFromNetwork() async {
    setState(() {
      _state = _state.copyWith(status: UiNetStatus.loading, error: null);
    });

    final resp = await widget.api.getFullScheduleDay(_selected);

    if (!mounted) return;

    if (resp.isSuccess) {
      setState(() {
        _state = ScreenDataState<DailySchedule?>(
          cache: resp.data,
          status: UiNetStatus.ok,
          error: null,
        );
      });
      return;
    }

    final f = resp.failure;
    final hasCache = _state.hasCache;

    if (hasCache) {
      setState(() {
        _state = _state.copyWith(
          status: UiNetStatus.offlineUsingCache,
          error: f,
        );
      });
      return;
    }

    setState(() {
      _state = _state.copyWith(
        status: UiNetStatus.errorNoCache,
        error: f,
      );
    });
  }

  void _onPickDate(DateTime d) {
    setState(() {
      _selected = d.dateOnly;
      _state = ScreenDataState.initial<DailySchedule?>(null);
    });
    unawaited(_bootstrap());
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateCenterDate(d));
  }

  Future<void> _pickDateFromCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      locale: const Locale('ru', 'RU'),
      helpText: 'Выбери дату',
      confirmText: 'ОК',
      cancelText: 'Отмена',
    );

    if (picked == null) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    if (d.weekday == DateTime.sunday) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Воскресенье — выходной, выбери другой день')),
      );
      return;
    }
    _onPickDate(d);
  }

  void _goToToday() {
    DateTime target = _today;
    if (_today.weekday == DateTime.sunday) {
      target = _today.add(const Duration(days: 1));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сегодня воскресенье — показан понедельник')),
      );
    }
    _onPickDate(target);
  }

  List<DateTime> _generateDateList(DateTime today) {
    final half = _totalDays ~/ 2;

    DateTime start = today;
    int countBefore = 0;
    while (countBefore < half) {
      start = start.subtract(const Duration(days: 1));
      if (start.weekday != DateTime.sunday) countBefore++;
    }

    DateTime end = today;
    int countAfter = 0;
    while (countAfter < half) {
      end = end.add(const Duration(days: 1));
      if (end.weekday != DateTime.sunday) countAfter++;
    }

    final result = <DateTime>[];
    DateTime current = start;
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.sunday) {
        result.add(current.dateOnly);
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  int _indexOfDate(DateTime date) => _dateList.indexWhere((d) => d.isSameDate(date));

  void _centerDateInRibbon(DateTime date) {
    if (!_datesCtrl.hasClients) return;
    final idx = _indexOfDate(date);
    if (idx < 0) return;

    final viewport = _datesCtrl.position.viewportDimension;
    final target = idx * _itemExtent - (viewport / 2) + (_itemExtent / 2);

    final maxExtent = _datesCtrl.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxExtent);
    _datesCtrl.jumpTo(clamped);
  }

  void _animateCenterDate(DateTime date) {
    if (!_datesCtrl.hasClients) return;
    final idx = _indexOfDate(date);
    if (idx < 0) return;

    final viewport = _datesCtrl.position.viewportDimension;
    final target = idx * _itemExtent - (viewport / 2) + (_itemExtent / 2);

    final maxExtent = _datesCtrl.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxExtent);

    _datesCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dfTitle = DateFormat('d MMMM, EEE');

    final schedule = _state.cache;

    final showOfflineBanner = _state.status == UiNetStatus.offlineUsingCache;
    final offlineReason = _state.error;
    final offlineSubtitle = offlineReason == null
        ? 'Показаны сохранённые данные.'
        : _isConnectivityish(offlineReason)
            ? 'Нет сети/сервер недоступен. Показаны сохранённые данные.'
            : 'Сервер вернул ошибку. Показаны сохранённые данные.';

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
            dfTitle.format(_selected),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(tooltip: 'Сегодня', onPressed: _goToToday, icon: const Icon(Icons.today_rounded)),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Выбрать дату',
              onPressed: _pickDateFromCalendar,
              icon: const Icon(Icons.calendar_month_rounded),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Обновить',
              onPressed: _fetchFromNetwork,
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
                    itemCount: _dateList.length,
                    itemBuilder: (_, i) {
                      final date = _dateList[i];
                      final isToday = date.isSameDate(_today);
                      final isSelected = date.isSameDate(_selected);
                      final isVacation = SchoolYear.isVacation(date);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: DateChip(
                          date: date,
                          isToday: isToday,
                          isSelected: isSelected,
                          isVacation: isVacation,
                          onTap: () {
                            if (date.isSameDate(_selected)) return;
                            _onPickDate(date);
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_state.status == UiNetStatus.loading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
        if (showOfflineBanner)
          SliverToBoxAdapter(
            child: OfflineBanner(
              title: 'Офлайн',
              subtitle: offlineSubtitle,
              onRetry: _fetchFromNetwork,
            ),
          ),
        if (_state.status == UiNetStatus.errorNoCache && schedule == null)
          SliverFillRemaining(
            child: ApiErrorView(
              failure: _state.error ??
                  ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: 'Не удалось загрузить данные'),
              onRetry: _fetchFromNetwork,
              vacationHint: SchoolYear.isVacation(_selected),
            ),
          )
        else if (schedule == null && _state.status != UiNetStatus.loading)
          SliverFillRemaining(
            child: EmptyView(
              title: 'Нет данных',
              subtitle: SchoolYear.isVacation(_selected) ? 'Сейчас каникулы.' : 'На этот день расписание пустое или ещё не загружено.',
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (schedule != null && schedule.lessons.isEmpty)
          SliverFillRemaining(
            child: EmptyView(
              title: 'Уроков нет',
              subtitle: SchoolYear.isVacation(_selected) ? 'Сейчас каникулы.' : 'На этот день расписание пустое.',
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (schedule != null)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final l = schedule.lessons[i];
                final now = DateTime.now();
                final isCurrent = _isCurrentLesson(l, now, _selected);
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LessonDetailsScreen(lesson: l)),
                  ),
                  child: CompactLessonCard(lesson: l, isCurrent: isCurrent),
                );
              },
              childCount: schedule.lessons.length,
            ),
          ),
      ],
    );
  }

  bool _isCurrentLesson(Lesson l, DateTime now, DateTime selectedDay) {
    if (!selectedDay.isSameDate(now)) return false;
    final s = _parseTime(selectedDay, l.startTime);
    final e = _parseTime(selectedDay, l.endTime);
    if (s == null || e == null) return false;
    return (now.isAfter(s) || now.isAtSameMomentAs(s)) && (now.isBefore(e) || now.isAtSameMomentAs(e));
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
