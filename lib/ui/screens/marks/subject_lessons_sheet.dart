import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/mark_average_simulator_sheet.dart';
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

class SubjectQuarterLessonsContent extends StatefulWidget {
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
  State<SubjectQuarterLessonsContent> createState() =>
      _SubjectQuarterLessonsContentState();
}

class _SubjectQuarterLessonsContentState
    extends State<SubjectQuarterLessonsContent> {
  bool _onlyWithMarks = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubjectQuarterLessonsBloc, SubjectQuarterLessonsState>(
      builder: (context, state) {
        final bloc = context.read<SubjectQuarterLessonsBloc>();
        final cs = Theme.of(context).colorScheme;

        final allRows = bloc.buildRows(widget.subjectName).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final today = DateTime.now().dateOnly;
        final rows = _onlyWithMarks
            ? allRows.where((row) => row.lesson.marks.isNotEmpty).toList()
            : allRows;
        final subjectMarks = allRows
            .expand((row) => row.lesson.marks)
            .where((mark) => mark.value != null && mark.value! > 0)
            .map((mark) => mark.value!)
            .toList();

        final passedLessonsCount =
            rows.where((row) => !row.date.isAfter(today)).length;
        final remainingLessonsCount =
            rows.where((row) => row.date.isAfter(today)).length;

        final showOfflineBanner = state.status == UiNetStatus.offlineUsingCache;
        final offlineSubtitle = state.error == null
            ? 'Показаны сохраненные данные.'
            : bloc.isConnectivityish(state.error)
            ? 'Нет сети или сервер недоступен. Показаны сохраненные данные.'
            : 'Сервер вернул ошибку. Показаны сохраненные данные.';

        Widget content;

        if (state.status == UiNetStatus.errorNoCache && state.error != null) {
          content = ApiErrorView(
            failure: state.error!,
            onRetry: () => bloc.add(SubjectQuarterLessonsRefreshRequested()),
            settings: bloc.api.settings,
          );
        } else if (state.data == null && state.status != UiNetStatus.loading) {
          content = EmptyView(
            title: 'Нет данных',
            subtitle: 'Не удалось загрузить уроки по предмету.',
            onRetry: () => bloc.add(SubjectQuarterLessonsRefreshRequested()),
          );
        } else if (rows.isEmpty && state.status != UiNetStatus.loading) {
          content = EmptyView(
            title: 'Пусто',
            subtitle: _onlyWithMarks
                ? 'Для этого предмета нет уроков с оценками.'
                : 'Уроков по этому предмету за выбранную четверть нет.',
            onRetry: () => bloc.add(SubjectQuarterLessonsRefreshRequested()),
          );
        } else {
          content = ListView(
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Все уроки за ${widget.term}-ю четверть',
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
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  FilterChip(
                    selected: _onlyWithMarks,
                    onSelected: (value) => setState(() => _onlyWithMarks = value),
                    label: const Text('Только с оценками'),
                    avatar: const Icon(Icons.filter_alt_rounded, size: 18),
                  ),
                  FilledButton.icon(
                    onPressed: () => showMarkAverageSimulatorSheet(
                      context,
                      title: 'Симулятор оценок',
                      subtitle: widget.subjectName,
                      initialMarks: subjectMarks,
                    ),
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text('Симулятор оценок'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.status == UiNetStatus.loading)
                const LinearProgressIndicator(minHeight: 2),
              if (showOfflineBanner) ...[
                const SizedBox(height: 8),
                OfflineBanner(
                  title: 'Офлайн',
                  subtitle: offlineSubtitle,
                  onRetry: () =>
                      bloc.add(SubjectQuarterLessonsRefreshRequested()),
                ),
              ],
              const SizedBox(height: 4),
              ...rows.map(
                (row) => _LessonRowTile(
                  row: row,
                  isToday: row.date.isSameDate(today),
                  isUpcoming: row.date.isAfter(today),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonDetailsScreen(
                        lesson: row.lesson,
                        api: bloc.api,
                      ),
                    ),
                  ),
                ),
              ),
              if (!widget.fullScreen) ...[
                const SizedBox(height: 12),
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
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: widget.fullScreen
                  ? 16
                  : 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: content,
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

class _LessonRowTile extends StatelessWidget {
  final SubjectLessonRow row;
  final bool isToday;
  final bool isUpcoming;
  final VoidCallback onTap;

  const _LessonRowTile({
    required this.row,
    required this.isToday,
    required this.isUpcoming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badgeText = isToday
        ? 'Сегодня'
        : isUpcoming
        ? 'Будет'
        : 'Было';
    final lessonNo = row.lesson.lessonNumber != null
        ? 'Урок №${row.lesson.lessonNumber}'
        : 'Урок';
    final time = (row.lesson.startTime != null && row.lesson.endTime != null)
        ? '${row.lesson.startTime} - ${row.lesson.endTime}'
        : null;
    final marksText = row.marksShort == '—' ? null : row.marksShort;
    final markParts = marksText == null
        ? const <String>[]
        : marksText
              .split(',')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: marksText != null
              ? cs.primaryContainer.withValues(alpha: 0.16)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: marksText != null
                ? cs.primary.withValues(alpha: 0.28)
                : cs.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.date.russianTextDateWithWeekday,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lessonNo,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
            if (time != null) ...[
              const SizedBox(height: 8),
              Text(
                time,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (markParts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: markParts
                    .map((part) => _MarkBadge(label: part))
                    .toList(),
              ),
            ],
            if (row.topic.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                row.topic,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkBadge extends StatelessWidget {
  final String label;

  const _MarkBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}
