import '../models/lesson.dart';
import '../models/mark.dart';
import '../../ui/ui_logic/mark_ui.dart';

class MarkEntry {
  final Mark mark;
  final Lesson? lesson;
  final DateTime lessonDate;

  MarkEntry({
    required this.mark,
    required this.lesson,
    required this.lessonDate,
  });

  String get subjectName => lesson?.subject?.nameRu ?? lesson?.subject?.name ?? 'Предмет';
  String? get teacherName => lesson?.teacher?.fio;
  String? get lessonTime => (lesson?.startTime != null && lesson?.endTime != null)
      ? '${lesson?.startTime}–${lesson?.endTime}'
      : null;

  DateTime? get markCreated => mark.createdAt ?? mark.updatedAt;

  String get label => MarkUi.label(mark);
}
