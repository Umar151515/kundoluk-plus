import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../domain/models/daily_schedules.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/mark.dart';

class SubjectLessonRow {
  final DateTime date;
  final Lesson lesson;
  final String marksShort;
  final String topic;

  const SubjectLessonRow({
    required this.date,
    required this.lesson,
    required this.marksShort,
    required this.topic,
  });
}

sealed class SubjectQuarterLessonsEvent {}

class SubjectQuarterLessonsStarted extends SubjectQuarterLessonsEvent {}

class SubjectQuarterLessonsRefreshRequested
    extends SubjectQuarterLessonsEvent {}

class SubjectQuarterLessonsState {
  final UiNetStatus status;
  final ApiFailure? error;
  final DailySchedules? data;

  const SubjectQuarterLessonsState({
    required this.status,
    required this.error,
    required this.data,
  });

  factory SubjectQuarterLessonsState.initial() {
    return const SubjectQuarterLessonsState(
      status: UiNetStatus.idle,
      error: null,
      data: null,
    );
  }

  SubjectQuarterLessonsState copyWith({
    UiNetStatus? status,
    ApiFailure? error,
    DailySchedules? data,
    bool clearError = false,
  }) {
    return SubjectQuarterLessonsState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
    );
  }
}

class SubjectQuarterLessonsBloc
    extends Bloc<SubjectQuarterLessonsEvent, SubjectQuarterLessonsState> {
  final KundolukApi api;
  final int term;

  SubjectQuarterLessonsBloc({required this.api, required this.term})
    : super(SubjectQuarterLessonsState.initial()) {
    on<SubjectQuarterLessonsStarted>(_onStarted);
    on<SubjectQuarterLessonsRefreshRequested>(_onRefresh);
  }

  Future<void> _onStarted(
    SubjectQuarterLessonsStarted event,
    Emitter<SubjectQuarterLessonsState> emit,
  ) async {
    final cached = await api.loadFullScheduleTermFromCache(term);
    if (cached != null) {
      emit(
        state.copyWith(
          data: cached,
          status: UiNetStatus.idle,
          clearError: true,
        ),
      );
    }
    await _fetchFromNetwork(emit);
  }

  Future<void> _onRefresh(
    SubjectQuarterLessonsRefreshRequested event,
    Emitter<SubjectQuarterLessonsState> emit,
  ) async {
    await _fetchFromNetwork(emit);
  }

  Future<void> _fetchFromNetwork(
    Emitter<SubjectQuarterLessonsState> emit,
  ) async {
    emit(state.copyWith(status: UiNetStatus.loading, clearError: true));
    final resp = await api.getFullScheduleTerm(term);

    if (resp.isSuccess) {
      emit(
        state.copyWith(
          data: resp.data,
          status: UiNetStatus.ok,
          clearError: true,
        ),
      );
      return;
    }

    if (state.data != null) {
      emit(
        state.copyWith(
          status: UiNetStatus.offlineUsingCache,
          error: resp.failure,
        ),
      );
    } else {
      emit(
        state.copyWith(status: UiNetStatus.errorNoCache, error: resp.failure),
      );
    }
  }

  List<SubjectLessonRow> buildRows(String subjectName) {
    final ds = state.data;
    if (ds == null) return const [];

    final loweredSubject = subjectName.trim().toLowerCase();
    final rows = <SubjectLessonRow>[];

    for (final day in ds.days) {
      for (final lesson in day.lessons) {
        final subj = (lesson.subject?.nameRu ?? lesson.subject?.name ?? '')
            .trim()
            .toLowerCase();
        if (subj != loweredSubject) continue;

        final topic = (lesson.topic?.name ?? '').trim();
        rows.add(
          SubjectLessonRow(
            date: day.date.dateOnly,
            lesson: lesson,
            topic: topic.isEmpty ? 'Тема не указана' : topic,
            marksShort: formatMarksShort(lesson.marks),
          ),
        );
      }
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  bool isConnectivityish(ApiFailure? f) {
    final kind = f?.kind;
    return kind == ApiErrorKind.network ||
        kind == ApiErrorKind.timeout ||
        kind == ApiErrorKind.badUrl;
  }

  static String formatMarksShort(List<Mark> marks) {
    if (marks.isEmpty) return '—';

    final parts = <String>[];
    for (final mark in marks) {
      final value = _markLabel(mark);
      if (value.trim().isEmpty || value.trim() == '—') continue;
      parts.add(value);
    }
    if (parts.isEmpty) return '—';
    return parts.join(', ');
  }

  static String _markLabel(Mark mark) {
    if (mark.value != null && mark.value != 0) return '${mark.value}';
    if ((mark.customMark ?? '').trim().isNotEmpty)
      return mark.customMark!.trim();
    if (mark.absent == true) return 'Н';
    if ((mark.lateMinutes ?? 0) > 0) return 'ОП';
    return '—';
  }
}
