import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  String toApiDate() => DateFormat('yyyy-MM-dd').format(this);

  String get russianWeekday => DateFormat('EEEE', 'ru_RU').format(this);

  String get russianWeekdayShort => DateFormat('EE', 'ru_RU').format(this);

  String get russianTextDate => DateFormat('d MMMM yyyy', 'ru_RU').format(this);

  String get russianTextDateWithWeekday =>
      DateFormat('d MMMM yyyy, EEEE', 'ru_RU').format(this);

  bool isSameDate(DateTime other) => year == other.year && month == other.month && day == other.day;

  DateTime get dateOnly => DateTime(year, month, day);
}
