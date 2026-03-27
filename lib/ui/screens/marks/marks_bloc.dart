import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/offline/screen_data_state.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/api/kundoluk_cache_parser.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/daily_schedule.dart';
import '../../../domain/models/daily_schedules.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/mark_entry.dart';
import '../../../domain/school_year/school_year.dart';

enum MarksSortMode { bySubject, byTeacherTime, byLessonDate }

sealed class MarksEvent {}

class MarksStarted extends MarksEvent {}

class MarksTermChanged extends MarksEvent {
  final int term;
  MarksTermChanged(this.term);
}

class MarksSortChanged extends MarksEvent {
  final MarksSortMode sortMode;
  MarksSortChanged(this.sortMode);
}

class MarksRefreshRequested extends MarksEvent {}

class MarksState {
  final int term;
  final MarksSortMode sortMode;
  final ScreenDataState<List<MarkEntry>> dataState;

  const MarksState({
    required this.term,
    required this.sortMode,
    required this.dataState,
  });

  factory MarksState.initial() {
    return MarksState(
      term: SchoolYear.getQuarter(DateTime.now(), nearest: true) ?? 1,
      sortMode: MarksSortMode.bySubject,
      dataState: ScreenDataState.initial<List<MarkEntry>>(<MarkEntry>[]),
    );
  }

  MarksState copyWith({
    int? term,
    MarksSortMode? sortMode,
    ScreenDataState<List<MarkEntry>>? dataState,
  }) {
    return MarksState(
      term: term ?? this.term,
      sortMode: sortMode ?? this.sortMode,
      dataState: dataState ?? this.dataState,
    );
  }
}

class MarksBloc extends Bloc<MarksEvent, MarksState> {
  final KundolukApi api;
  final AuthStore auth;

  MarksBloc({required this.api, required this.auth})
    : super(MarksState.initial()) {
    on<MarksStarted>(_onStarted);
    on<MarksTermChanged>(_onTermChanged);
    on<MarksSortChanged>(_onSortChanged);
    on<MarksRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onStarted(MarksStarted event, Emitter<MarksState> emit) async {
    await _reload(emit, state.term, preserveStatus: true);
  }

  Future<void> _onTermChanged(
    MarksTermChanged event,
    Emitter<MarksState> emit,
  ) async {
    await _reload(emit, event.term, preserveStatus: false);
  }

  void _onSortChanged(MarksSortChanged event, Emitter<MarksState> emit) {
    emit(state.copyWith(sortMode: event.sortMode));
  }

  Future<void> _onRefreshRequested(
    MarksRefreshRequested event,
    Emitter<MarksState> emit,
  ) async {
    await _fetchFromNetwork(emit, state.term);
  }

  Future<void> _reload(
    Emitter<MarksState> emit,
    int term, {
    required bool preserveStatus,
  }) async {
    emit(
      state.copyWith(
        term: term,
        dataState: preserveStatus
            ? state.dataState
            : ScreenDataState<List<MarkEntry>>(
                cache: const <MarkEntry>[],
                status: UiNetStatus.idle,
                error: null,
              ),
      ),
    );
    await _loadFromCache(emit, term);
    await _fetchFromNetwork(emit, term);
  }

  Future<void> _loadFromCache(Emitter<MarksState> emit, int term) async {
    final keyAbsent = CacheKeys.marks(term, true);
    final keyPresent = CacheKeys.marks(term, false);
    final entries = <MarkEntry>[];

    Future<void> addFromCache(String key) async {
      final cached = await auth.loadFromCache(key);
      if (cached == null) return;

      final lessons = KundolukCacheParser.parseLessons(
        KundolukCacheParser.extractActionResult(cached),
      );

      for (final lesson in lessons) {
        for (final mark in lesson.marks) {
          final d = lesson.lessonDay?.toLocal();
          if (d == null) continue;
          entries.add(
            MarkEntry(
              mark: mark,
              lesson: lesson,
              lessonDate: DateTime(d.year, d.month, d.day),
            ),
          );
        }
      }
    }

    await addFromCache(keyPresent);
    await addFromCache(keyAbsent);

    emit(
      state.copyWith(
        term: term,
        dataState: state.dataState.copyWith(cache: _uniqueEntries(entries)),
      ),
    );
  }

  Future<void> _fetchFromNetwork(Emitter<MarksState> emit, int term) async {
    emit(
      state.copyWith(
        term: term,
        dataState: state.dataState.copyWith(
          status: UiNetStatus.loading,
          error: null,
        ),
      ),
    );

    final marksResp = await api.getScheduleWithMarks(term, absent: false);
    final absentResp = await api.getScheduleWithMarks(term, absent: true);

    if (marksResp.isSuccess && absentResp.isSuccess) {
      final entries = <MarkEntry>[];
      _addFromDailySchedules(entries, marksResp.data);
      _addFromDailySchedules(entries, absentResp.data);

      emit(
        state.copyWith(
          term: term,
          dataState: ScreenDataState<List<MarkEntry>>(
            cache: _uniqueEntries(entries),
            status: UiNetStatus.ok,
            error: null,
          ),
        ),
      );
      return;
    }

    final failure = marksResp.failure ?? absentResp.failure;
    if (state.dataState.hasCache) {
      emit(
        state.copyWith(
          term: term,
          dataState: state.dataState.copyWith(
            status: UiNetStatus.offlineUsingCache,
            error: failure,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          term: term,
          dataState: state.dataState.copyWith(
            status: UiNetStatus.errorNoCache,
            error: failure,
          ),
        ),
      );
    }
  }

  Future<Lesson?> resolveFullLessonForEntry(MarkEntry entry) async {
    final dayDate = entry.lessonDate;
    final resp = await api.getFullScheduleDay(dayDate);
    DailySchedule? day = resp.data;

    if (!resp.isSuccess || day == null) {
      day = KundolukCacheParser.parseDailySchedule(
        await auth.loadFromCache(CacheKeys.schedule(dayDate)),
        dayDate,
      );
    }

    if (day == null) return null;

    final uid = entry.lesson?.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      for (final lesson in day.lessons) {
        if (lesson.uid == uid) return lesson;
      }
    }

    return _findLessonFallback(day.lessons, entry);
  }

  void _addFromDailySchedules(
    List<MarkEntry> entries,
    DailySchedules schedules,
  ) {
    for (final day in schedules.days) {
      for (final lesson in day.lessons) {
        for (final mark in lesson.marks) {
          entries.add(
            MarkEntry(mark: mark, lesson: lesson, lessonDate: day.date),
          );
        }
      }
    }
  }

  List<MarkEntry> _uniqueEntries(List<MarkEntry> entries) {
    final map = <String, MarkEntry>{};
    for (final entry in entries) {
      final key =
          entry.mark.uid ??
          '${entry.lesson?.uid ?? ''}:${entry.lessonDate.toIso8601String()}:${entry.mark.createdAt?.toIso8601String() ?? ''}:${entry.mark.value ?? ''}:${entry.mark.customMark ?? ''}:${entry.mark.absent ?? ''}:${entry.mark.lateMinutes ?? ''}:${entry.mark.absentType ?? ''}';
      map[key] = entry;
    }
    return map.values.toList();
  }

  Lesson? _findLessonFallback(List<Lesson> lessons, MarkEntry entry) {
    final targetNum = entry.lesson?.lessonNumber;
    final targetSubject = entry.subjectName.trim().toLowerCase();

    Lesson? best;
    for (final lesson in lessons) {
      final subject = (lesson.subject?.nameRu ?? lesson.subject?.name ?? '')
          .trim()
          .toLowerCase();
      if (subject != targetSubject) continue;
      if (targetNum != null && lesson.lessonNumber == targetNum) return lesson;
      best ??= lesson;
    }
    return best;
  }
}
