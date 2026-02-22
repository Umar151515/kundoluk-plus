import '../extensions/datetime_x.dart';

abstract class CacheKeys {
  static String schedule(DateTime day) => 'schedule:${day.toApiDate()}';
  static String marks(int term, bool absent) => 'marks:term=$term:absent=${absent ? 1 : 0}';
  static String quarterMarks() => 'qmarks:all';
}
