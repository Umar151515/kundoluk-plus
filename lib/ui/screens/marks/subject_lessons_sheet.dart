import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import '../today/lesson_details_screen.dart';
import 'subject_quarter_lessons_bloc.dart';

class SubjectLessonsSheet extends StatelessWidget {
  final KundolukApi api;
  final int term;
  final String subjectName;

  const SubjectLessonsSheet({
    super.key,
    required this.api,
    required this.term,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SubjectQuarterLessonsBloc(api: api, term: term)
            ..add(SubjectQuarterLessonsStarted()),
      child: SubjectQuarterLessonsContent(
        subjectName: subjectName,
        term: term,
        fullScreen: false,
      ),
    );
  }
}

class SubjectQuarterLessonsContent extends StatelessWidget {
  final String subjectName;
  final int term;
  final bool fullScreen;

  const SubjectQuarterLessonsContent({
    super.key,
    required this.subjectName,
    required this.term,
    required this.fullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubjectQuarterLessonsBloc, SubjectQuarterLessonsState>(
      builder: (context, state) {
        final bloc = context.read<SubjectQuarterLessonsBloc>();
        final cs = Theme.of(context).colorScheme;

        final rows = bloc.buildRows(subjectName);
        final today = DateTime.now().dateOnly;
        final passedLessonsCount = rows
            .where((row) => !row.date.isAfter(today))
            .length;
        final remainingLessonsCount = rows
            .where((row) => row.date.isAfter(today))
            .length;
        final groupedRows = <DateTime, List<SubjectLessonRow>>{};
        for (final row in rows) {
          groupedRows.putIfAbsent(row.date, () => []).add(row);
        }
        final sortedDates = groupedRows.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        final showOfflineBanner = state.status == UiNetStatus.offlineUsingCache;
        final offlineSubtitle = state.error == null
            ? 'Показаны сохраненные данные.'
            : bloc.isConnectivityish(state.error)
            ? 'Нет сети или сервер недоступен. Показаны сохраненные данные.'
            : 'Сервер вернул ошибку. Показаны сохраненные данные.';

        final body = Column(
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
                        subjectName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Все уроки за $term-ю четверть',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: state.status == UiNetStatus.loading
                      ? null
                      : () => bloc.add(SubjectQuarterLessonsRefreshRequested()),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.status == UiNetStatus.loading)
              const LinearProgressIndicator(minHeight: 2),
            if (state.status == UiNetStatus.errorNoCache && state.error != null)
              Expanded(
                child: ApiErrorView(
                  failure: state.error!,
                  onRetry: () =>
                      bloc.add(SubjectQuarterLessonsRefreshRequested()),
                  settings: bloc.api.settings,
                ),
              )
            else if (state.data == null && state.status != UiNetStatus.loading)
              Expanded(
                child: EmptyView(
                  title: 'Нет данных',
                  subtitle: 'Не удалось загрузить уроки по предмету.',
                  onRetry: () =>
                      bloc.add(SubjectQuarterLessonsRefreshRequested()),
                ),
              )
            else if (rows.isEmpty && state.status != UiNetStatus.loading)
              Expanded(
                child: EmptyView(
                  title: 'Пусто',
                  subtitle: 'Уроков по этому предмету за выбранную четверть нет.',
                  onRetry: () =>
                      bloc.add(SubjectQuarterLessonsRefreshRequested()),
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
                        onRetry: () =>
                            bloc.add(SubjectQuarterLessonsRefreshRequested()),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CountChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Прошло',
                          value: '$passedLessonsCount',
                        ),
                        _CountChip(
                          icon: Icons.schedule_rounded,
                          label: 'Осталось',
                          value: '$remainingLessonsCount',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...sortedDates.map((date) {
                      final dayRows = groupedRows[date]!..sort(
                        (a, b) => (a.lesson.lessonNumber ?? 999).compareTo(
                          b.lesson.lessonNumber ?? 999,
                        ),
                      );
                      return _LessonDaySection(
                        date: date,
                        rows: dayRows,
                        isToday: date.isSameDate(today),
                        isUpcoming: date.isAfter(today),
                        api: bloc.api,
                      );
                    }),
                    if (!fullScreen) ...[
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
                  ],
                ),
              ),
          ],
        );

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: fullScreen
                  ? 16
                  : 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: body,
            ),
          ),
        );
      },
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CountChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LessonDaySection extends StatelessWidget {
  final DateTime date;
  final List<SubjectLessonRow> rows;
  final bool isToday;
  final bool isUpcoming;
  final KundolukApi api;

  const _LessonDaySection({
    required this.date,
    required this.rows,
    required this.isToday,
    required this.isUpcoming,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badgeText = isToday
        ? 'Сегодня'
        : isUpcoming
        ? 'Будет'
        : 'Было';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date.russianTextDateWithWeekday,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday
                      ? cs.primaryContainer
                      : isUpcoming
                      ? cs.tertiaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isToday
                        ? cs.onPrimaryContainer
                        : isUpcoming
                        ? cs.onTertiaryContainer
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => _LessonRowTile(
              row: row,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonDetailsScreen(
                    lesson: row.lesson,
                    api: api,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonRowTile extends StatelessWidget {
  final SubjectLessonRow row;
  final VoidCallback onTap;

  const _LessonRowTile({
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lessonNo = row.lesson.lessonNumber != null
        ? 'Урок №${row.lesson.lessonNumber}'
        : 'Урок';
    final time = (row.lesson.startTime != null && row.lesson.endTime != null)
        ? '${row.lesson.startTime} - ${row.lesson.endTime}'
        : null;
    final marksText = row.marksShort == '—' ? null : row.marksShort;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lessonNo,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (time != null)
                  Text(
                    time,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              row.topic,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (marksText != null) ...[
              const SizedBox(height: 8),
              Text(
                'Оценки: $marksText',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
