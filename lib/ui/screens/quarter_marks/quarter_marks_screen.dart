import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/offline/screen_data_state.dart';
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

class QuarterMarksScreen extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const QuarterMarksScreen({super.key, required this.api, required this.auth});

  @override
  State<QuarterMarksScreen> createState() => _QuarterMarksScreenState();
}

class _QuarterMarksScreenState extends State<QuarterMarksScreen> {
  ScreenDataState<List<QuarterMark>> _state = ScreenDataState.initial<List<QuarterMark>>(<QuarterMark>[]);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadFromCache();
    unawaited(_fetchFromNetwork());
  }

  List<QuarterMark> _unique(List<QuarterMark> list) {
    final map = <String, QuarterMark>{};
    for (final m in list) {
      final id = m.objectId ?? '${m.subjectNameRu}:${m.quarter}:${m.quarterMark}:${m.customMark}';
      map[id] = m;
    }
    return map.values.toList()
      ..sort((a, b) {
        final sA = a.subjectNameRu ?? a.subjectNameKg ?? '';
        final sB = b.subjectNameRu ?? b.subjectNameKg ?? '';
        final c = sA.compareTo(sB);
        if (c != 0) return c;
        return (a.quarter ?? 0).compareTo(b.quarter ?? 0);
      });
  }

  Future<void> _loadFromCache() async {
    final key = CacheKeys.quarterMarks();
    final json = await widget.auth.loadFromCache(key);

    List<QuarterMark> parsed = const [];
    if (json != null) {
      try {
        final action = json.containsKey('actionResult') ? json['actionResult'] : json;
        final results = (action as List?) ?? const [];
        final all = <QuarterMark>[];
        for (final r in results) {
          final rm = (r is Map ? r.cast<String, dynamic>() : <String, dynamic>{});
          final qms = (rm['quarterMarks'] as List?) ?? const [];
          for (final q in qms) {
            final qm = QuarterMark.fromJson(q is Map ? q.cast<String, dynamic>() : <String, dynamic>{});
            if (qm != null) all.add(qm);
          }
        }
        parsed = _unique(all);
      } catch (_) {
        parsed = const [];
      }
    }

    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(cache: parsed, status: _state.status, error: _state.error);
    });
  }

  Future<void> _fetchFromNetwork() async {
    setState(() => _state = _state.copyWith(status: UiNetStatus.loading, error: null));

    final resp = await widget.api.getAllQuarterMarks();
    if (!mounted) return;

    if (resp.isSuccess) {
      setState(() {
        _state = ScreenDataState<List<QuarterMark>>(cache: resp.data, status: UiNetStatus.ok, error: null);
      });
    } else {
      if (_state.hasCache) {
        setState(() => _state = _state.copyWith(status: UiNetStatus.offlineUsingCache, error: resp.failure));
      } else {
        setState(() => _state = _state.copyWith(status: UiNetStatus.errorNoCache, error: resp.failure));
      }
    }
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
                      if (_state.status == UiNetStatus.loading)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      IconButton(
                        tooltip: 'Обновить',
                        onPressed: _fetchFromNetwork,
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
              subtitle: 'Показаны сохранённые итоги.',
              onRetry: _fetchFromNetwork,
            ),
          ),
        if (_state.status == UiNetStatus.errorNoCache && data.isEmpty)
          SliverFillRemaining(
            child: ApiErrorView(
              failure: _state.error ??
                  ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: 'Не удалось загрузить итоги'),
              onRetry: _fetchFromNetwork,
            ),
          )
        else if (data.isEmpty && _state.status != UiNetStatus.loading)
          SliverFillRemaining(
            child: EmptyView(
              title: 'Оценок нет',
              subtitle: 'Сервер не вернул четвертные оценки или данные ещё не загружены.',
              onRetry: _fetchFromNetwork,
            ),
          )
        else
          _buildQuarterSliver(data),
      ],
    );
  }

  Widget _buildQuarterSliver(List<QuarterMark> data) {
    final cs = Theme.of(context).colorScheme;

    final bySubject = <String, List<QuarterMark>>{};
    for (final m in data) {
      final subject = (m.subjectNameRu ?? m.subjectNameKg ?? 'Неизвестный предмет').trim();
      bySubject.putIfAbsent(subject, () => []).add(m);
    }
    final subjects = bySubject.keys.toList()..sort();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final subject = subjects[index];
          final list = [...bySubject[subject]!]..sort((a, b) => (a.quarter ?? 0).compareTo(b.quarter ?? 0));

          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: list.map((m) => QuarterChip(mark: m, subjectName: subject)).toList(),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: subjects.length,
      ),
    );
  }
}
