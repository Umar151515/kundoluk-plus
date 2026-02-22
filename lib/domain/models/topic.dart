import '../../core/extensions/map_x.dart';

class Topic {
  final int? code;
  final String? name;
  final String? short;
  final DateTime? lessonDay;

  Topic({this.code, this.name, this.short, this.lessonDay});

  static Topic fromJson(Map<String, dynamic> json) {
    return Topic(
      code: json.parseInt('code'),
      name: json['name']?.toString(),
      short: json['short']?.toString(),
      lessonDay: json.parseDateOnly('lessonDay'),
    );
  }
}
