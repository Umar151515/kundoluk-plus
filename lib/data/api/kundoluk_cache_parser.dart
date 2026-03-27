import '../../domain/models/daily_schedule.dart';
import '../../domain/models/daily_schedules.dart';
import '../../domain/models/lesson.dart';
import '../../domain/models/quarter_mark.dart';

class KundolukCacheParser {
  const KundolukCacheParser._();

  static Object? extractActionResult(Map<String, dynamic> json) {
    return json.containsKey('actionResult') ? json['actionResult'] : json;
  }

  static List<Lesson> parseLessons(Object? source) {
    final list = source as List? ?? const [];
    return list
        .map((item) => Lesson.fromJson(_asMap(item)))
        .whereType<Lesson>()
        .toList()
      ..sort(_compareLessons);
  }

  static DailySchedule? parseDailySchedule(
    Map<String, dynamic>? json,
    DateTime date,
  ) {
    if (json == null) return null;

    try {
      final lessons = parseLessons(extractActionResult(json));
      return DailySchedule(date: _dateOnly(date), lessons: lessons);
    } catch (_) {
      return null;
    }
  }

  static DailySchedules? parseDailySchedules(Map<String, dynamic>? json) {
    if (json == null) return null;

    try {
      return _groupLessonsByDay(parseLessons(extractActionResult(json)));
    } catch (_) {
      return null;
    }
  }

  static List<QuarterMark> parseQuarterMarks(Map<String, dynamic>? json) {
    if (json == null) return const [];

    try {
      final results = extractActionResult(json) as List? ?? const [];
      final all = <QuarterMark>[];

      for (final result in results) {
        final quarterMarks = (_asMap(result)['quarterMarks'] as List?) ?? const [];
        for (final quarterMark in quarterMarks) {
          final parsed = QuarterMark.fromJson(_asMap(quarterMark));
          if (parsed != null) {
            all.add(parsed);
          }
        }
      }

      return uniqueQuarterMarks(all);
    } catch (_) {
      return const [];
    }
  }

  static List<QuarterMark> uniqueQuarterMarks(List<QuarterMark> list) {
    final unique = <String, QuarterMark>{};
    for (final mark in list) {
      final key =
          mark.objectId ??
          '${mark.subjectNameRu}:${mark.quarter}:${mark.quarterMark}:${mark.customMark}';
      unique[key] = mark;
    }

    return unique.values.toList()
      ..sort((a, b) {
        final subjectA = a.subjectNameRu ?? a.subjectNameKg ?? '';
        final subjectB = b.subjectNameRu ?? b.subjectNameKg ?? '';
        final subjectCompare = subjectA.compareTo(subjectB);
        if (subjectCompare != 0) return subjectCompare;
        return (a.quarter ?? 0).compareTo(b.quarter ?? 0);
      });
  }

  static DailySchedules _groupLessonsByDay(List<Lesson> lessons) {
    final daysMap = <DateTime, List<Lesson>>{};
    for (final lesson in lessons) {
      final day = lesson.lessonDay?.toLocal();
      if (day == null) continue;

      final normalized = _dateOnly(day);
      daysMap.putIfAbsent(normalized, () => []).add(lesson);
    }

    final days = daysMap.entries
        .map(
          (entry) => DailySchedule(
            date: entry.key,
            lessons: [...entry.value]..sort(_compareLessons),
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return DailySchedules(days: days);
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static int _compareLessons(Lesson a, Lesson b) {
    return (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999);
  }
}
