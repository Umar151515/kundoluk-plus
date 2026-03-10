import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/offline/screen_data_state.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/quarter_mark.dart';

sealed class QuarterMarksEvent {}

class QuarterMarksStarted extends QuarterMarksEvent {}

class QuarterMarksRefreshRequested extends QuarterMarksEvent {}

class QuarterMarksState {
  final ScreenDataState<List<QuarterMark>> dataState;

  const QuarterMarksState({required this.dataState});

  factory QuarterMarksState.initial() {
    return QuarterMarksState(
      dataState: ScreenDataState.initial<List<QuarterMark>>(<QuarterMark>[]),
    );
  }

  QuarterMarksState copyWith({ScreenDataState<List<QuarterMark>>? dataState}) {
    return QuarterMarksState(dataState: dataState ?? this.dataState);
  }
}

class QuarterMarksBloc extends Bloc<QuarterMarksEvent, QuarterMarksState> {
  final KundolukApi api;
  final AuthStore auth;

  QuarterMarksBloc({required this.api, required this.auth})
    : super(QuarterMarksState.initial()) {
    on<QuarterMarksStarted>(_onStarted);
    on<QuarterMarksRefreshRequested>(_onRefresh);
  }

  Future<void> _onStarted(
    QuarterMarksStarted event,
    Emitter<QuarterMarksState> emit,
  ) async {
    await _loadFromCache(emit);
    await _fetchFromNetwork(emit);
  }

  Future<void> _onRefresh(
    QuarterMarksRefreshRequested event,
    Emitter<QuarterMarksState> emit,
  ) async {
    await _fetchFromNetwork(emit);
  }

  Future<void> _loadFromCache(Emitter<QuarterMarksState> emit) async {
    final json = await auth.loadFromCache(CacheKeys.quarterMarks());
    List<QuarterMark> parsed = const [];

    if (json != null) {
      try {
        final action = json.containsKey('actionResult')
            ? json['actionResult']
            : json;
        final results = (action as List?) ?? const [];
        final all = <QuarterMark>[];

        for (final r in results) {
          final resultMap = (r is Map
              ? r.cast<String, dynamic>()
              : <String, dynamic>{});
          final qms = (resultMap['quarterMarks'] as List?) ?? const [];
          for (final q in qms) {
            final qm = QuarterMark.fromJson(
              q is Map ? q.cast<String, dynamic>() : <String, dynamic>{},
            );
            if (qm != null) all.add(qm);
          }
        }
        parsed = _unique(all);
      } catch (_) {
        parsed = const [];
      }
    }

    emit(state.copyWith(dataState: state.dataState.copyWith(cache: parsed)));
  }

  Future<void> _fetchFromNetwork(Emitter<QuarterMarksState> emit) async {
    emit(
      state.copyWith(
        dataState: state.dataState.copyWith(
          status: UiNetStatus.loading,
          error: null,
        ),
      ),
    );
    final resp = await api.getAllQuarterMarks();

    if (resp.isSuccess) {
      emit(
        state.copyWith(
          dataState: ScreenDataState<List<QuarterMark>>(
            cache: _unique(resp.data),
            status: UiNetStatus.ok,
            error: null,
          ),
        ),
      );
      return;
    }

    if (state.dataState.hasCache) {
      emit(
        state.copyWith(
          dataState: state.dataState.copyWith(
            status: UiNetStatus.offlineUsingCache,
            error: resp.failure,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          dataState: state.dataState.copyWith(
            status: UiNetStatus.errorNoCache,
            error: resp.failure,
          ),
        ),
      );
    }
  }

  List<QuarterMark> _unique(List<QuarterMark> list) {
    final map = <String, QuarterMark>{};
    for (final m in list) {
      final id =
          m.objectId ??
          '${m.subjectNameRu}:${m.quarter}:${m.quarterMark}:${m.customMark}';
      map[id] = m;
    }
    return map.values.toList()..sort((a, b) {
      final sA = a.subjectNameRu ?? a.subjectNameKg ?? '';
      final sB = b.subjectNameRu ?? b.subjectNameKg ?? '';
      final c = sA.compareTo(sB);
      if (c != 0) return c;
      return (a.quarter ?? 0).compareTo(b.quarter ?? 0);
    });
  }
}
