import 'package:flutter/foundation.dart';

import '../network/api_failure.dart';
import 'ui_net_status.dart';

class _Absent {
  const _Absent();
}

const _absent = _Absent();

@immutable
class ScreenDataState<T> {
  final T cache;
  final UiNetStatus status;
  final ApiFailure? error;

  const ScreenDataState({
    required this.cache,
    required this.status,
    required this.error,
  });

  bool get hasCache {
    final c = cache;
    if (c == null) return false;
    if (c is List) return c.isNotEmpty;
    return true;
  }

  ScreenDataState<T> copyWith({
    Object? cache = _absent, // важно: Object? + sentinel
    UiNetStatus? status,
    ApiFailure? error,
  }) {
    final nextCache = identical(cache, _absent) ? this.cache : cache as T;
    return ScreenDataState<T>(
      cache: nextCache,
      status: status ?? this.status,
      error: error,
    );
  }

  static ScreenDataState<T> initial<T>(T emptyCache) =>
      ScreenDataState(cache: emptyCache, status: UiNetStatus.idle, error: null);
}
