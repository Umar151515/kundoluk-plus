import '../../core/extensions/map_x.dart';

class LessonTeacher {
  final int? pin;
  final String? pinAsString;
  final String? firstName;
  final String? lastName;
  final String? midName;

  LessonTeacher({
    this.pin,
    this.pinAsString,
    this.firstName,
    this.lastName,
    this.midName,
  });

  String get fio => [
        lastName,
        firstName,
        midName,
      ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).join(' ');

  static LessonTeacher fromJson(Map<String, dynamic> json) {
    return LessonTeacher(
      pin: json.parseInt('pin'),
      pinAsString: (json['pinAsString'] ?? json['pin_as_string'])?.toString(),
      firstName: (json['firstName'] ?? json['first_name'])?.toString(),
      lastName: (json['lastName'] ?? json['last_name'])?.toString(),
      midName: (json['midName'] ?? json['mid_name'])?.toString(),
    );
  }
}
