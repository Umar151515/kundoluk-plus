import 'dart:math';

import '../../core/extensions/datetime_x.dart';

class SchoolYear {
  static const Map<int, Map<String, List<int>>> quarters = {
    1: {'start': [9, 1], 'end': [11, 4]},
    2: {'start': [11, 10], 'end': [12, 30]},
    3: {'start': [1, 12], 'end': [3, 5]},
    4: {'start': [3, 9], 'end': [5, 31]},
  };

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

  static bool isVacation(DateTime target) => getQuarter(target, nearest: false) == null;
}
