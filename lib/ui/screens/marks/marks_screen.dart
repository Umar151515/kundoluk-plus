import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/offline/screen_data_state.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/daily_schedule.dart';
import '../../../domain/models/daily_schedules.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/mark_entry.dart';
import '../../../domain/school_year/school_year.dart';
import '../../ui_logic/mark_stats.dart';
import '../../ui_logic/mark_ui.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import '../today/lesson_details_screen.dart';
import 'mark_chip.dart';
import 'subject_lessons_sheet.dart';

enum MarksSortMode { bySubject, byTeacherTime, byLessonDate }

class MarksScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const MarksScreen({super.key, required this.api, required this.auth});

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  int _term = SchoolYear.getQuarter(DateTime.now(), nearest: true) ?? 1;
  MarksSortMode _sort = MarksSortMode.bySubject;

  ScreenDataState<List<MarkEntry>> _state = ScreenDataState.initial<List<MarkEntry>>(<MarkEntry>[]);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadFromCache();
    unawaited(_fetchFromNetwork());
  }

  List<MarkEntry> _uniqueEntries(List<MarkEntry> entries) {
    final map = <String, MarkEntry>{};
    for (final e in entries) {
      final k = e.mark.uid ??
          '${e.lesson?.uid ?? ''}:${e.lessonDate.toIso8601String()}:${e.mark.createdAt?.toIso8601String() ?? ''}:${e.mark.value ?? ''}:${e.mark.customMark ?? ''}:${e.mark.absent ?? ''}:${e.mark.lateMinutes ?? ''}:${e.mark.absentType ?? ''}';
      map[k] = e;
    }
    return map.values.toList();
  }

  Future<void> _loadFromCache() async {
    final keyAbsent = CacheKeys.marks(_term, true);
    final keyPresent = CacheKeys.marks(_term, false);

    final entries = <MarkEntry>[];

    Future<void> addFromCache(String key) async {
      final json = await widget.auth.loadFromCache(key);
      if (json == null) return;

      try {
        final action = json.containsKey('actionResult') ? json['actionResult'] : json;
        final list = (action as List?) ?? const [];
        final lessons = list
            .map((e) => Lesson.fromJson(e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}))
            .whereType<Lesson>()
            .toList();

        for (final l in lessons) {
          for (final m in l.marks) {
            final d = l.lessonDay?.toLocal();
            if (d == null) continue;
            entries.add(
              MarkEntry(
                mark: m,
                lesson: l,
                lessonDate: DateTime(d.year, d.month, d.day),
              ),
            );
          }
        }
      } catch (_) {}
    }

    await addFromCache(keyPresent);
    await addFromCache(keyAbsent);

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(
        cache: _uniqueEntries(entries),
        status: _state.status,
        error: _state.error,
      );
    });
  }

  Future<void> _fetchFromNetwork() async {
    setState(() {
      _state = _state.copyWith(status: UiNetStatus.loading, error: null);
    });

    final marksResp = await widget.api.getScheduleWithMarks(_term, absent: false);
    final absentResp = await widget.api.getScheduleWithMarks(_term, absent: true);

    if (!mounted) return;

    if (marksResp.isSuccess && absentResp.isSuccess) {
      final entries = <MarkEntry>[];

      void addFrom(DailySchedules ds) {
        for (final day in ds.days) {
          for (final lesson in day.lessons) {
            for (final mark in lesson.marks) {
              entries.add(MarkEntry(mark: mark, lesson: lesson, lessonDate: day.date));
            }
          }
        }
      }

      addFrom(marksResp.data);
      addFrom(absentResp.data);

      setState(() {
        _state = ScreenDataState<List<MarkEntry>>(
          cache: _uniqueEntries(entries),
          status: UiNetStatus.ok,
          error: null,
        );
      });
      return;
    }

    final failure = marksResp.failure ?? absentResp.failure;
    final hasCache = _state.hasCache;

    if (hasCache) {
      setState(() {
        _state = _state.copyWith(status: UiNetStatus.offlineUsingCache, error: failure);
      });
    } else {
      setState(() {
        _state = _state.copyWith(status: UiNetStatus.errorNoCache, error: failure);
      });
    }
  }

  Future<void> _openSubjectMenu(String subjectName) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true, 
      builder: (_) => SafeArea(
        child: SubjectLessonsSheet(
          api: widget.api,
          auth: widget.auth,
          term: _term,
          subjectName: subjectName,
        ),
      ),
    );
  }

  Future<void> _openFullLessonForEntry(MarkEntry entry) async {
    final d = entry.lessonDate;

    final resp = await widget.api.getFullScheduleDay(d);
    if (!mounted) return;

    DailySchedule? day = resp.data;
    if (!resp.isSuccess || day == null) {
      final cached = await widget.auth.loadFromCache(CacheKeys.schedule(d));

      if (!mounted) return;

      if (cached != null) {
        try {
          final action = cached.containsKey('actionResult') ? cached['actionResult'] : cached;
          final list = (action as List?) ?? const [];
          final lessons = list
              .map((e) => Lesson.fromJson(e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}))
              .whereType<Lesson>()
              .toList()
            ..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
          day = DailySchedule(date: d, lessons: lessons);
        } catch (_) {
          day = null;
        }
      }
    }

    if (day == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp.failure?.message ?? 'Не удалось открыть полный урок.'),
        ),
      );
      return;
    }

    Lesson? target;
    final uid = entry.lesson?.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      target = day.lessons.where((l) => l.uid == uid).cast<Lesson?>().firstWhere((x) => x != null, orElse: () => null);
    }

    target ??= _findLessonFallback(day.lessons, entry);

    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось найти урок в полном расписании дня.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonDetailsScreen(lesson: target!)),
    );
  }

  Lesson? _findLessonFallback(List<Lesson> lessons, MarkEntry entry) {
    final targetNum = entry.lesson?.lessonNumber;
    final targetSubj = (entry.subjectName).trim().toLowerCase();

    Lesson? best;

    for (final l in lessons) {
      final subj = (l.subject?.nameRu ?? l.subject?.name ?? '').trim().toLowerCase();
      if (subj != targetSubj) continue;

      if (targetNum != null && l.lessonNumber == targetNum) {
        best = l;
        break;
      }

      best ??= l;
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = _state.cache;
    final showOfflineBanner = _state.status == UiNetStatus.offlineUsingCache;

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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_rounded),
                          const SizedBox(width: 10),
                          const Text('Четверть:', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _term,
                            underline: const SizedBox.shrink(),
                            items: [1, 2, 3, 4]
                                .map((q) => DropdownMenuItem(value: q, child: Text('$q')))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _term = v;
                                _state = const ScreenDataState(cache: <MarkEntry>[], status: UiNetStatus.idle, error: null);
                              });
                              unawaited(_bootstrap());
                            },
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Обновить',
                            onPressed: _fetchFromNetwork,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: DropdownButton<MarksSortMode>(
                      value: _sort,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      borderRadius: BorderRadius.circular(16),
                      items: const [
                        DropdownMenuItem(
                          value: MarksSortMode.bySubject,
                          child: Row(
                            children: [
                              Icon(Icons.subject_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('По предметам'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: MarksSortMode.byTeacherTime,
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('По времени выставления'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: MarksSortMode.byLessonDate,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('По дате урока'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _sort = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_state.status == UiNetStatus.loading) const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ),
        ),
        if (showOfflineBanner)
          SliverToBoxAdapter(
            child: OfflineBanner(
              title: 'Офлайн',
              subtitle: 'Показаны сохранённые оценки.',
              onRetry: _fetchFromNetwork,
            ),
          ),
        if (_state.status == UiNetStatus.errorNoCache && data.isEmpty)
          SliverFillRemaining(
            child: ApiErrorView(
              failure: _state.error ??
                  ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: 'Не удалось загрузить оценки'),
              onRetry: _fetchFromNetwork,
              settings: widget.api.settings,
            ),
          )
        else if (data.isEmpty && _state.status != UiNetStatus.loading)
          SliverFillRemaining(
            child: EmptyView(
              title: 'Пусто',
              subtitle: 'За выбранную четверть данных нет (или они ещё не загружены).',
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (_sort == MarksSortMode.bySubject)
          _buildSubjectGroupedSliver(data)
        else
          _buildFlatMarksList(data),
      ],
    );
  }

  Widget _buildFlatMarksList(List<MarkEntry> data) {
    final sorted = [...data];
    if (_sort == MarksSortMode.byTeacherTime) {
      sorted.sort((a, b) => (b.markCreated ?? DateTime(1970)).compareTo(a.markCreated ?? DateTime(1970)));
    } else {
      sorted.sort((a, b) => b.lessonDate.compareTo(a.lessonDate));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = sorted[index];
          return _buildMarkEntryCard(entry, _sort);
        },
        childCount: sorted.length,
      ),
    );
  }

  Widget _buildSubjectGroupedSliver(List<MarkEntry> data) {
    final bySubject = <String, List<MarkEntry>>{};
    for (final e in data) {
      final s = e.subjectName.trim();
      bySubject.putIfAbsent(s, () => []).add(e);
    }
    final subjects = bySubject.keys.toList()..sort();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, subjectIndex) {
          final subject = subjects[subjectIndex];
          final entries = bySubject[subject]!;
          final sortedEntries = [...entries]
            ..sort((a, b) {
              final dateCompare = a.lessonDate.compareTo(b.lessonDate);
              if (dateCompare != 0) return dateCompare;
              return (a.markCreated ?? DateTime(1970)).compareTo(b.markCreated ?? DateTime(1970));
            });

          final stats = MarkStats.ofEntries(sortedEntries);
          final cs = Theme.of(context).colorScheme;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openSubjectMenu(subject),
            child: Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (stats.avg != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Средняя: ${stats.avg!.toStringAsFixed(2)}',
                              style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Всего: ${stats.total} • Оценок: ${stats.numericCount} • Отметок: ${stats.notesCount}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: sortedEntries.take(60).map((entry) => MarkChip(entry: entry)).toList(),
                    ),
                    if (sortedEntries.length > 60) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Показаны первые 60 из ${sortedEntries.length}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: subjects.length,
      ),
    );
  }

  Widget _buildMarkEntryCard(MarkEntry entry, MarksSortMode mode) {
    String subtitle;
    if (mode == MarksSortMode.byTeacherTime) {
      final dt = entry.markCreated?.toLocal();
      final when = dt != null ? DateFormat('d MMM HH:mm').format(dt) : 'неизвестно';
      final type = MarkUi.typeTitle(entry.mark);
      subtitle = 'Выставлено: $when • $type • ${entry.label}';
    } else {
      final d = DateFormat('d MMM').format(entry.lessonDate);
      final type = MarkUi.typeTitle(entry.mark);
      subtitle = 'Дата урока: $d • $type • ${entry.label}';
    }

    final cs = Theme.of(context).colorScheme;
    final subject = entry.subjectName;
    final teacher = entry.teacherName;
    final value = entry.label;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openFullLessonForEntry(entry),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Text(
                value,
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (teacher != null && teacher.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Учитель: $teacher', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
