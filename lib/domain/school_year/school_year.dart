import 'dart:math';

import '../../core/extensions/datetime_x.dart';

class SchoolYear {
  static const Map<int, Map<String, List<int>>> quarters = {
    1: {'start': [9, 1], 'end': [11, 4]},
    2: {'start': [11, 10], 'end': [12, 30]},
    3: {'start': [1, 12], 'end': [3, 5]},
    4: {'start': [3, 9], 'end': [5, 31]},
  };

  static const List<Map<String, List<int>>> intraQuarterVacations = [
    {
      'start': [5, 1],
      'end': [5, 9],
    },
  ];

  static int? getQuarter(DateTime target, {bool nearest = false}) {
    final yearStart = target.month >= 9 ? target.year : target.year - 1;

    final qDates = <int, (DateTime, DateTime)>{};
    for (final entry in quarters.entries) {
      final q = entry.key;
      final start = entry.value['start']!;
      final end = entry.value['end']!;
      final y = q <= 2 ? yearStart : yearStart + 1;
      qDates[q] = (DateTime(y, start[0], start[1]), DateTime(y, end[0], end[1]));
    }

    final td = target.dateOnly;

    for (final e in qDates.entries) {
      final (s, en) = e.value;
      if (!td.isBefore(s) && !td.isAfter(en)) return e.key;
    }

    if (!nearest) return null;

    int bestQ = 1;
    int bestDiff = 1 << 30;
    for (final e in qDates.entries) {
      final (s, en) = e.value;
      final d1 = (td.difference(s).inDays).abs();
      final d2 = (td.difference(en).inDays).abs();
      final d = min(d1, d2);
      if (d < bestDiff) {
        bestDiff = d;
        bestQ = e.key;
      }
    }
    return bestQ;
  }

  static (DateTime, DateTime)? getQuarterBounds(int quarter, DateTime target) {
    final raw = quarters[quarter];
    if (raw == null) return null;

    final yearStart = target.month >= 9 ? target.year : target.year - 1;
    final year = quarter <= 2 ? yearStart : yearStart + 1;
    final start = raw['start']!;
    final end = raw['end']!;
    return (DateTime(year, start[0], start[1]), DateTime(year, end[0], end[1]));
  }

  static bool isIntraQuarterVacation(DateTime target) {
    final td = target.dateOnly;
    final yearStart = target.month >= 9 ? target.year : target.year - 1;

    for (final period in intraQuarterVacations) {
      final startRaw = period['start']!;
      final endRaw = period['end']!;
      final year = startRaw[0] >= 9 ? yearStart : yearStart + 1;
      final start = DateTime(year, startRaw[0], startRaw[1]);
      final end = DateTime(year, endRaw[0], endRaw[1]);
      if (!td.isBefore(start) && !td.isAfter(end)) return true;
    }

    return false;
  }

  static bool isVacation(DateTime target) =>
      getQuarter(target, nearest: false) == null || isIntraQuarterVacation(target);

  static double? getQuarterProgress(DateTime target) {
    final quarter = getQuarter(target, nearest: false);
    if (quarter == null) return null;

    final bounds = getQuarterBounds(quarter, target);
    if (bounds == null) return null;

    final (start, end) = bounds;
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 100;

    final elapsedDays = target.dateOnly.difference(start).inDays.clamp(
      0,
      totalDays,
    );
    return ((elapsedDays / totalDays) * 100).toDouble();
  }
}
