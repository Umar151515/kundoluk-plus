import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/quarter_mark.dart';
import '../../widgets/api_error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/offline_banner.dart';
import 'quarter_chip.dart';
import 'quarter_marks_bloc.dart';

class QuarterMarksScreen extends StatelessWidget {
  final KundolukApi api;
  final AuthStore auth;

  const QuarterMarksScreen({super.key, required this.api, required this.auth});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          QuarterMarksBloc(api: api, auth: auth)..add(QuarterMarksStarted()),
      child: const _QuarterMarksView(),
    );
  }
}

class _QuarterMarksView extends StatelessWidget {
  const _QuarterMarksView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuarterMarksBloc, QuarterMarksState>(
      builder: (context, state) {
        final bloc = context.read<QuarterMarksBloc>();
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
                preferredSize: const Size.fromHeight(66),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events_rounded),
                      title: const Text('Итоговые/четвертные оценки'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dataState.status == UiNetStatus.loading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          IconButton(
                            tooltip: 'Обновить',
                            onPressed: () =>
                                bloc.add(QuarterMarksRefreshRequested()),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showOfflineBanner)
              SliverToBoxAdapter(
                child: OfflineBanner(
                  title: 'Офлайн',
                  subtitle: 'Показаны сохраненные итоги.',
                  onRetry: () => bloc.add(QuarterMarksRefreshRequested()),
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
                        message: 'Не удалось загрузить итоги',
                      ),
                  onRetry: () => bloc.add(QuarterMarksRefreshRequested()),
                ),
              )
            else if (data.isEmpty && dataState.status != UiNetStatus.loading)
              SliverFillRemaining(
                child: EmptyView(
                  title: 'Оценок нет',
                  subtitle:
                      'Сервер не вернул четвертные оценки или данные еще не загружены.',
                  onRetry: () => bloc.add(QuarterMarksRefreshRequested()),
                ),
              )
            else
              _buildQuarterSliver(data),
          ],
        );
      },
    );
  }

  Widget _buildQuarterSliver(List<QuarterMark> data) {
    final bySubject = <String, List<QuarterMark>>{};
    for (final mark in data) {
      final subject =
          (mark.subjectNameRu ?? mark.subjectNameKg ?? 'Неизвестный предмет')
              .trim();
      bySubject.putIfAbsent(subject, () => []).add(mark);
    }
    final subjects = bySubject.keys.toList()..sort();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final cs = Theme.of(context).colorScheme;
        final subject = subjects[index];
        final list = [...bySubject[subject]!]
          ..sort((a, b) => (a.quarter ?? 0).compareTo(b.quarter ?? 0));

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: list
                      .map((m) => QuarterChip(mark: m, subjectName: subject))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      }, childCount: subjects.length),
    );
  }
}
