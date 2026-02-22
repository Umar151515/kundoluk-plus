import '../../core/extensions/map_x.dart';

class Task {
  final int? code;
  final String? name;
  final String? note;
  final DateTime? lessonDay;

  Task({this.code, this.name, this.note, this.lessonDay});

  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      code: json.parseInt('code'),
      name: json['name']?.toString(),
      note: json['note']?.toString(),
      lessonDay: json.parseDateOnly('lessonDay'),
    );
  }
}
