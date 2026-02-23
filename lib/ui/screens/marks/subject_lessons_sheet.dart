import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/daily_schedules.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/mark.dart';
import '../../ui_logic/mark_ui.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import '../today/lesson_details_screen.dart';

class SubjectLessonsSheet extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  final int term;
  final String subjectName;

  const SubjectLessonsSheet({
    super.key,
    required this.api,
    required this.auth,
    required this.term,
    required this.subjectName,
  });

  @override
  State<SubjectLessonsSheet> createState() => _SubjectLessonsSheetState();
}

class _SubjectLessonsSheetState extends State<SubjectLessonsSheet> {
  UiNetStatus _status = UiNetStatus.idle;
  ApiFailure? _error;

  DailySchedules? _data;

  DateTime get _today => DateTime.now().dateOnly;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await widget.api.loadFullScheduleTermFromCache(widget.term);
    if (mounted && cached != null) {
      setState(() {
        _data = cached;
        _status = UiNetStatus.idle;
        _error = null;
      });
    }

    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    setState(() {
      _status = UiNetStatus.loading;
      _error = null;
    });

    final resp = await widget.api.getFullScheduleTerm(widget.term);

    if (!mounted) return;

    if (resp.isSuccess) {
      setState(() {
        _data = resp.data;
        _status = UiNetStatus.ok;
        _error = null;
      });
      return;
    }

    if (_data != null) {
      setState(() {
        _status = UiNetStatus.offlineUsingCache;
        _error = resp.failure;
      });
    } else {
      setState(() {
        _status = UiNetStatus.errorNoCache;
        _error = resp.failure;
      });
    }
  }

  List<_SubjectLessonRow> _buildRows(DailySchedules ds) {
    final rows = <_SubjectLessonRow>[];

    for (final day in ds.days) {
      for (final lesson in day.lessons) {
        final subj = (lesson.subject?.nameRu ?? lesson.subject?.name ?? '').trim();
        if (subj.toLowerCase() != widget.subjectName.trim().toLowerCase()) continue;

        final topic = (lesson.topic?.name ?? '').trim();
        final marksLabel = _formatMarksShort(lesson.marks);

        rows.add(
          _SubjectLessonRow(
            date: day.date.dateOnly,
            lesson: lesson,
            topic: topic.isEmpty ? 'Тема не указана' : topic,
            marksShort: marksLabel,
          ),
        );
      }
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  String _formatMarksShort(List<Mark> marks) {
    if (marks.isEmpty) return '—';

    final parts = marks.map(MarkUi.label).where((s) => s.trim().isNotEmpty && s.trim() != '—').toList();
    if (parts.isEmpty) return '—';
    return parts.join(', ');
  }

  bool _isConnectivityish(ApiFailure? f) {
    final k = f?.kind;
    return k == ApiErrorKind.network || k == ApiErrorKind.timeout || k == ApiErrorKind.badUrl;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ds = _data;
    final allRows = ds == null ? <_SubjectLessonRow>[] : _buildRows(ds);

    final upcoming = allRows.where((r) => r.date.isAfter(_today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final pastOrToday = allRows.where((r) => !r.date.isAfter(_today)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final showOfflineBanner = _status == UiNetStatus.offlineUsingCache;
    final offlineSubtitle = _error == null
        ? 'Показаны сохранённые данные.'
        : _isConnectivityish(_error)
            ? 'Нет сети/сервер недоступен. Показаны сохранённые данные.'
            : 'Сервер вернул ошибку. Показаны сохранённые данные.';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.subject_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subjectName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Все уроки за ${widget.term}-ю четверть',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: _status == UiNetStatus.loading ? null : _fetchFromNetwork,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_status == UiNetStatus.loading) const LinearProgressIndicator(minHeight: 2),


              if (_status == UiNetStatus.errorNoCache && _error != null)
                Expanded(
                  child: ApiErrorView(
                    failure: _error!,
                    onRetry: _fetchFromNetwork,
                    settings: widget.api.settings,
                  ),
                )
              else if (ds == null && _status != UiNetStatus.loading)
                Expanded(
                  child: EmptyView(
                    title: 'Нет данных',
                    subtitle: 'Не удалось загрузить уроки по предмету. Попробуй обновить.',
                    onRetry: _fetchFromNetwork,
                  ),
                )
              else if (ds != null && allRows.isEmpty && _status != UiNetStatus.loading)
                Expanded(
                  child: EmptyView(
                    title: 'Пусто',
                    subtitle: 'Уроков по этому предмету за выбранную четверть нет.',
                    onRetry: _fetchFromNetwork,
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (showOfflineBanner)
                        OfflineBanner(
                          title: 'Офлайн',
                          subtitle: offlineSubtitle,
                          onRetry: _fetchFromNetwork,
                        ),
                        
                      const SizedBox(height: 10),

                      _SummaryCard(
                        total: allRows.length,
                        past: pastOrToday.length,
                        upcoming: upcoming.length,
                        term: widget.term,
                      ),
                      const SizedBox(height: 10),

                      if (upcoming.isNotEmpty) ...[
                        _SectionTitle(
                          icon: Icons.schedule_rounded,
                          title: 'Ещё будут',
                          subtitle: 'Уроки, которые ещё не начались',
                        ),
                        const SizedBox(height: 8),
                        ...upcoming.map((r) => _LessonRowTile(
                              row: r,
                              isUpcoming: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => LessonDetailsScreen(lesson: r.lesson)),
                              ),
                            )),
                        const SizedBox(height: 14),
                      ],

                      if (pastOrToday.isNotEmpty) ...[
                        _SectionTitle(
                          icon: Icons.history_rounded,
                          title: 'Уже были',
                          subtitle: 'Уроки, которые уже прошли (включая сегодня)',
                        ),
                        const SizedBox(height: 8),
                        ...pastOrToday.map((r) => _LessonRowTile(
                              row: r,
                              isUpcoming: false,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => LessonDetailsScreen(lesson: r.lesson)),
                              ),
                            )),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Закрыть'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectLessonRow {
  final DateTime date;
  final Lesson lesson;
  final String marksShort;
  final String topic;

  _SubjectLessonRow({
    required this.date,
    required this.lesson,
    required this.marksShort,
    required this.topic,
  });
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int past;
  final int upcoming;
  final int term;

  const _SummaryCard({
    required this.total,
    required this.past,
    required this.upcoming,
    required this.term,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
                Icons.summarize_rounded,
                color: cs.onPrimaryContainer,
              ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Сводка', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Всего уроков: $total • Прошло: $past • Будет: $upcoming',
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonRowTile extends StatelessWidget {
  final _SubjectLessonRow row;
  final bool isUpcoming;
  final VoidCallback onTap;

  const _LessonRowTile({
    required this.row,
    required this.isUpcoming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = row.date;

    final month = DateFormat('MMM', 'ru_RU').format(date).toLowerCase();
    final day = DateFormat('d', 'ru_RU').format(date);

    final marks = row.marksShort.trim();
    final hasMarks = marks.isNotEmpty && marks != '—';

    final bg = isUpcoming ? cs.tertiaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerHighest;
    final border = isUpcoming ? cs.tertiary : cs.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border.withValues(alpha: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      month,
                      style: TextStyle(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMarks ? 'Оценки/отметки: $marks' : 'Оценок/отметок нет',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: hasMarks ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      row.topic,
                      style: TextStyle(color: cs.onSurfaceVariant),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
