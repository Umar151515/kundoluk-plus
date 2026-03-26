import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/extensions/datetime_x.dart';
import '../../../core/offline/screen_data_state.dart';
import '../../../core/offline/ui_net_status.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../../domain/models/daily_schedule.dart';
import '../../../domain/models/lesson.dart';

sealed class TodayEvent {}

class TodayStarted extends TodayEvent {}

class TodayDateSelected extends TodayEvent {
  final DateTime date;
  TodayDateSelected(this.date);
}

class TodayRefreshRequested extends TodayEvent {}

class TodayJumpToTodayRequested extends TodayEvent {}

class TodayState {
  final DateTime today;
  final DateTime effectiveToday;
  final DateTime selectedDate;
  final List<DateTime> dateList;
  final ScreenDataState<DailySchedule?> dataState;
  final bool shouldNotifySundayAutoMove;
  final bool shouldNotifySundayBlocked;
  final int ribbonJumpVersion;

  const TodayState({
    required this.today,
    required this.effectiveToday,
    required this.selectedDate,
    required this.dateList,
    required this.dataState,
    this.shouldNotifySundayAutoMove = false,
    this.shouldNotifySundayBlocked = false,
    this.ribbonJumpVersion = 0,
  });

  factory TodayState.initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveToday = today.weekday == DateTime.sunday
        ? today.add(const Duration(days: 1))
        : today;
    return TodayState(
      today: today,
      effectiveToday: effectiveToday.dateOnly,
      selectedDate: effectiveToday.dateOnly,
      dateList: _generateDateList(today),
      dataState: ScreenDataState.initial<DailySchedule?>(null),
      shouldNotifySundayAutoMove: today.weekday == DateTime.sunday,
    );
  }

  TodayState copyWith({
    DateTime? today,
    DateTime? effectiveToday,
    DateTime? selectedDate,
    List<DateTime>? dateList,
    ScreenDataState<DailySchedule?>? dataState,
    bool? shouldNotifySundayAutoMove,
    bool? shouldNotifySundayBlocked,
    int? ribbonJumpVersion,
  }) {
    return TodayState(
      today: today ?? this.today,
      effectiveToday: effectiveToday ?? this.effectiveToday,
      selectedDate: selectedDate ?? this.selectedDate,
      dateList: dateList ?? this.dateList,
      dataState: dataState ?? this.dataState,
      shouldNotifySundayAutoMove: shouldNotifySundayAutoMove ?? false,
      shouldNotifySundayBlocked: shouldNotifySundayBlocked ?? false,
      ribbonJumpVersion: ribbonJumpVersion ?? this.ribbonJumpVersion,
    );
  }

  static List<DateTime> _generateDateList(DateTime today) {
    const totalDays = 178;
    final half = totalDays ~/ 2;

    DateTime start = today;
    int countBefore = 0;
    while (countBefore < half) {
      start = start.subtract(const Duration(days: 1));
      if (start.weekday != DateTime.sunday) countBefore++;
    }

    DateTime end = today;
    int countAfter = 0;
    while (countAfter < half) {
      end = end.add(const Duration(days: 1));
      if (end.weekday != DateTime.sunday) countAfter++;
    }

    final result = <DateTime>[];
    DateTime current = start;
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.sunday) {
        result.add(current.dateOnly);
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }
}

class TodayBloc extends Bloc<TodayEvent, TodayState> {
  final KundolukApi api;
  final AuthStore auth;
  int _activeRequestToken = 0;

  TodayBloc({required this.api, required this.auth})
    : super(TodayState.initial()) {
    on<TodayStarted>(_onStarted);
    on<TodayDateSelected>(_onDateSelected);
    on<TodayRefreshRequested>(_onRefresh);
    on<TodayJumpToTodayRequested>(_onJumpToToday);
  }

  Future<void> _onStarted(TodayStarted event, Emitter<TodayState> emit) async {
    await _reload(emit, state.selectedDate, preserveStatus: true);
  }

  Future<void> _onDateSelected(
    TodayDateSelected event,
    Emitter<TodayState> emit,
  ) async {
    final picked = event.date.dateOnly;
    if (picked.weekday == DateTime.sunday) {
      emit(state.copyWith(shouldNotifySundayBlocked: true));
      return;
    }
    await _reload(emit, picked, preserveStatus: false);
  }

  Future<void> _onRefresh(
    TodayRefreshRequested event,
    Emitter<TodayState> emit,
  ) async {
    final date = state.selectedDate;
    final token = ++_activeRequestToken;
    await _fetchFromNetwork(emit, date, token);
  }

  Future<void> _onJumpToToday(
    TodayJumpToTodayRequested event,
    Emitter<TodayState> emit,
  ) async {
    final target = state.effectiveToday;
    emit(state.copyWith(ribbonJumpVersion: state.ribbonJumpVersion + 1));
    if (state.selectedDate.isSameDate(target)) return;
    await _reload(emit, target, preserveStatus: false);
  }

  Future<void> _reload(
    Emitter<TodayState> emit,
    DateTime date, {
    required bool preserveStatus,
  }) async {
    final normalized = date.dateOnly;
    final token = ++_activeRequestToken;
    emit(
      state.copyWith(
        selectedDate: normalized,
        dataState: preserveStatus
            ? state.dataState
            : ScreenDataState.initial<DailySchedule?>(null),
      ),
    );
    await _loadFromCache(emit, normalized, token);
    await _fetchFromNetwork(emit, normalized, token);
  }

  bool _isRequestStale(int token, DateTime date) {
    return token != _activeRequestToken || !state.selectedDate.isSameDate(date);
  }

  Future<void> _loadFromCache(
    Emitter<TodayState> emit,
    DateTime date,
    int token,
  ) async {
    final key = CacheKeys.schedule(date);
    final json = await auth.loadFromCache(key);
    if (_isRequestStale(token, date)) return;

    DailySchedule? parsed;
    if (json != null) {
      try {
        final action = json.containsKey('actionResult')
            ? json['actionResult']
            : json;
        final list = (action as List?) ?? const [];
        final lessons =
            list
                .map(
                  (e) => Lesson.fromJson(
                    e is Map ? e.cast<String, dynamic>() : <String, dynamic>{},
                  ),
                )
                .whereType<Lesson>()
                .toList()
              ..sort(
                (a, b) =>
                    (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999),
              );
        parsed = DailySchedule(date: date, lessons: lessons);
      } catch (_) {
        parsed = null;
      }
    }

    emit(
      state.copyWith(
        selectedDate: date,
        dataState: state.dataState.copyWith(cache: parsed),
      ),
    );
  }

  Future<void> _fetchFromNetwork(
    Emitter<TodayState> emit,
    DateTime date,
    int token,
  ) async {
    if (_isRequestStale(token, date)) return;
    emit(
      state.copyWith(
        selectedDate: date,
        dataState: state.dataState.copyWith(
          status: UiNetStatus.loading,
          error: null,
        ),
      ),
    );

    final resp = await api.getFullScheduleDay(date);
    if (_isRequestStale(token, date)) return;

    if (resp.isSuccess) {
      emit(
        state.copyWith(
          selectedDate: date,
          dataState: ScreenDataState<DailySchedule?>(
            cache: resp.data,
            status: UiNetStatus.ok,
            error: null,
          ),
        ),
      );
      return;
    }

    final failure = resp.failure;
    if (state.dataState.hasCache) {
      emit(
        state.copyWith(
          selectedDate: date,
          dataState: state.dataState.copyWith(
            status: UiNetStatus.offlineUsingCache,
            error: failure,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          selectedDate: date,
          dataState: state.dataState.copyWith(
            status: UiNetStatus.errorNoCache,
            error: failure,
          ),
        ),
      );
    }
  }

  static bool isConnectivityish(ApiFailure? f) {
    final k = f?.kind;
    return k == ApiErrorKind.network ||
        k == ApiErrorKind.timeout ||
        k == ApiErrorKind.badUrl;
  }
}
