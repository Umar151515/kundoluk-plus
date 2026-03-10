import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/mark_entry.dart';
import '../../ui_logic/mark_stats.dart';
import '../../ui_logic/mark_ui.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import '../today/lesson_details_screen.dart';
import 'mark_chip.dart';
import 'marks_bloc.dart';
import 'subject_lessons_sheet.dart';

class MarksScreen extends StatelessWidget {
  final KundolukApi api;
  final AuthStore auth;

  const MarksScreen({super.key, required this.api, required this.auth});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MarksBloc(api: api, auth: auth)..add(MarksStarted()),
      child: const _MarksView(),
    );
  }
}

class _MarksView extends StatelessWidget {
  const _MarksView();

  Future<void> _openSubjectMenu(
    BuildContext context,
    int term,
    String subjectName,
  ) async {
    final bloc = context.read<MarksBloc>();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: SubjectLessonsSheet(
          api: bloc.api,
          term: term,
          subjectName: subjectName,
        ),
      ),
    );
  }

  Future<void> _openFullLessonForEntry(
    BuildContext context,
    MarkEntry entry,
  ) async {
    final bloc = context.read<MarksBloc>();
    final lesson = await bloc.resolveFullLessonForEntry(entry);

    if (!context.mounted) return;
    if (lesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть полный урок.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonDetailsScreen(lesson: lesson, api: bloc.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MarksBloc, MarksState>(
      builder: (context, state) {
        final bloc = context.read<MarksBloc>();
        final cs = Theme.of(context).colorScheme;
        final dataState = state.dataState;
        final data = dataState.cache;
        final showOfflineBanner =
            dataState.status == UiNetStatus.offlineUsingCache;

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
                              const Text(
                                'Четверть:',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: state.term,
                                underline: const SizedBox.shrink(),
                                items: [1, 2, 3, 4]
                                    .map(
                                      (q) => DropdownMenuItem(
                                        value: q,
                                        child: Text('$q'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  bloc.add(MarksTermChanged(v));
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Обновить',
                                onPressed: () =>
                                    bloc.add(MarksRefreshRequested()),
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
                          value: state.sortMode,
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
                            bloc.add(MarksSortChanged(v));
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (dataState.status == UiNetStatus.loading)
                        const LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ),
            ),
            if (showOfflineBanner)
              SliverToBoxAdapter(
                child: OfflineBanner(
                  title: 'Офлайн',
                  subtitle: 'Показаны сохраненные оценки.',
                  onRetry: () => bloc.add(MarksRefreshRequested()),
                ),
              ),
            if (dataState.status == UiNetStatus.errorNoCache && data.isEmpty)
              SliverFillRemaining(
                child: ApiErrorView(
                  failure:
                      dataState.error ??
                      ApiFailure(
                        kind: ApiErrorKind.unknown,
                        title: 'Ошибка',
                        message: 'Не удалось загрузить оценки',
                      ),
                  onRetry: () => bloc.add(MarksRefreshRequested()),
                  settings: bloc.api.settings,
                ),
              )
            else if (data.isEmpty && dataState.status != UiNetStatus.loading)
              SliverFillRemaining(
                child: EmptyView(
                  title: 'Пусто',
                  subtitle: 'За выбранную четверть данных нет.',
                  onRetry: () => bloc.add(MarksRefreshRequested()),
                ),
              )
            else if (state.sortMode == MarksSortMode.bySubject)
              _buildSubjectGroupedSliver(
                context,
                data,
                state.term,
                onSubjectTap: (subject) =>
                    _openSubjectMenu(context, state.term, subject),
              )
            else
              _buildFlatMarksList(
                context,
                data,
                state.sortMode,
                onEntryTap: (entry) => _openFullLessonForEntry(context, entry),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFlatMarksList(
    BuildContext context,
    List<MarkEntry> data,
    MarksSortMode sortMode, {
    required ValueChanged<MarkEntry> onEntryTap,
  }) {
    final sorted = [...data];
    if (sortMode == MarksSortMode.byTeacherTime) {
      sorted.sort(
        (a, b) => (b.markCreated ?? DateTime(1970)).compareTo(
          a.markCreated ?? DateTime(1970),
        ),
      );
    } else {
      sorted.sort((a, b) => b.lessonDate.compareTo(a.lessonDate));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = sorted[index];
        return _buildMarkEntryCard(
          context,
          entry,
          sortMode,
          onTap: () => onEntryTap(entry),
        );
      }, childCount: sorted.length),
    );
  }

  Widget _buildSubjectGroupedSliver(
    BuildContext context,
    List<MarkEntry> data,
    int term, {
    required ValueChanged<String> onSubjectTap,
  }) {
    final bySubject = <String, List<MarkEntry>>{};
    for (final entry in data) {
      final subject = entry.subjectName.trim();
      bySubject.putIfAbsent(subject, () => []).add(entry);
    }
    final subjects = bySubject.keys.toList()..sort();
    final cs = Theme.of(context).colorScheme;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, subjectIndex) {
        final subject = subjects[subjectIndex];
        final entries = bySubject[subject]!;
        final sortedEntries = [...entries]
          ..sort((a, b) {
            final dateCompare = a.lessonDate.compareTo(b.lessonDate);
            if (dateCompare != 0) return dateCompare;
            return (a.markCreated ?? DateTime(1970)).compareTo(
              b.markCreated ?? DateTime(1970),
            );
          });

        final stats = MarkStats.ofEntries(sortedEntries);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSubjectTap(subject),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (stats.avg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Средняя: ${stats.avg!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Всего: ${stats.total} • Оценок: ${stats.numericCount} • Отметок: ${stats.notesCount}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sortedEntries
                        .take(60)
                        .map((entry) => MarkChip(entry: entry))
                        .toList(),
                  ),
                  if (sortedEntries.length > 60) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Показаны первые 60 из ${sortedEntries.length}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }, childCount: subjects.length),
    );
  }

  Widget _buildMarkEntryCard(
    BuildContext context,
    MarkEntry entry,
    MarksSortMode mode, {
    required VoidCallback onTap,
  }) {
    String subtitle;
    if (mode == MarksSortMode.byTeacherTime) {
      final dt = entry.markCreated?.toLocal();
      final when = dt != null
          ? DateFormat('d MMM HH:mm').format(dt)
          : 'неизвестно';
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
      onTap: onTap,
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
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                  if ((teacher ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Учитель: $teacher',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
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
