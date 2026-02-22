import '../../core/extensions/datetime_x.dart';
import 'daily_schedule.dart';

class DailySchedules {
  final List<DailySchedule> days;
  const DailySchedules({required this.days});

  DailySchedule? getByDate(DateTime date) {
    final d = date.dateOnly;
    for (final x in days) {
      if (x.date.dateOnly == d) return x;
    }
    return null;
  }
}
