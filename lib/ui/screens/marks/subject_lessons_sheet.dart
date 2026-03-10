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
        final upcoming = rows.where((r) => r.date.isAfter(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final pastOrToday = rows.where((r) => !r.date.isAfter(today)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

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
                  subtitle:
                      'Уроков по этому предмету за выбранную четверть нет.',
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
                    if (upcoming.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const _SectionTitle(
                        icon: Icons.schedule_rounded,
                        title: 'Еще будут',
                        subtitle: 'Уроки, которые еще не начались',
                      ),
                      const SizedBox(height: 8),
                      ...upcoming.map(
                        (row) => _LessonRowTile(
                          row: row,
                          isUpcoming: true,
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
                    ],
                    if (pastOrToday.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _SectionTitle(
                        icon: Icons.history_rounded,
                        title: 'Уже были',
                        subtitle: 'Уроки, которые уже прошли',
                      ),
                      const SizedBox(height: 8),
                      ...pastOrToday.map(
                        (row) => _LessonRowTile(
                          row: row,
                          isUpcoming: false,
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
                    ],
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
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
  final SubjectLessonRow row;
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
    final subject =
        row.lesson.subject?.nameRu ?? row.lesson.subject?.name ?? 'Предмет';
    final day =
        '${row.date.day.toString().padLeft(2, '0')}.${row.date.month.toString().padLeft(2, '0')}.${row.date.year}';
    final lessonNo = row.lesson.lessonNumber != null
        ? 'Урок №${row.lesson.lessonNumber}'
        : 'Урок';
    final time = (row.lesson.startTime != null && row.lesson.endTime != null)
        ? '${row.lesson.startTime} - ${row.lesson.endTime}'
        : 'Время не указано';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUpcoming
                ? cs.primary.withValues(alpha: 0.35)
                : cs.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$day • $lessonNo',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
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
            Text(subject, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              row.topic,
              style: TextStyle(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              'Оценки: ${row.marksShort}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
