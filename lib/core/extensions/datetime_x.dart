import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  String toApiDate() => DateFormat('yyyy-MM-dd').format(this);

  bool isSameDate(DateTime other) => year == other.year && month == other.month && day == other.day;

  DateTime get dateOnly => DateTime(year, month, day);
}
