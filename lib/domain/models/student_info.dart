import '../../core/extensions/map_x.dart';

class StudentInfo {
  final String? scheduleItemId;
  final DateTime? lessonDay;
  final DateTime? lessonDayAsDateOnly;
  final String? objectId;
  final String? schoolId;
  final String? gradeId;
  final String? okpo;
  final int? pin;
  final String? pinAsString;
  final int? grade;
  final String? letter;
  final String? name;
  final String? lastName;
  final String? firstName;
  final String? midName;
  final String? email;
  final String? phone;
  final String? groupId;
  final String? subjectGroupName;
  final String? districtName;
  final String? cityName;

  StudentInfo({
    this.scheduleItemId,
    this.lessonDay,
    this.lessonDayAsDateOnly,
    this.objectId,
    this.schoolId,
    this.gradeId,
    this.okpo,
    this.pin,
    this.pinAsString,
    this.grade,
    this.letter,
    this.name,
    this.lastName,
    this.firstName,
    this.midName,
    this.email,
    this.phone,
    this.groupId,
    this.subjectGroupName,
    this.districtName,
    this.cityName,
  });

  static StudentInfo fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      scheduleItemId: json['scheduleItemId']?.toString(),
      lessonDay: json.parseDateTime('lessonDay'),
      lessonDayAsDateOnly: json.parseDateOnly('lessonDayAsDateOnly'),
      objectId: json['objectId']?.toString(),
      schoolId: json['schoolId']?.toString(),
      gradeId: json['gradeId']?.toString(),
      okpo: json['okpo']?.toString(),
      pin: json.parseInt('pin'),
      pinAsString: json['pinAsString']?.toString(),
      grade: json.parseInt('grade'),
      letter: json['letter']?.toString(),
      name: json['name']?.toString(),
      lastName: json['lastName']?.toString(),
      firstName: json['firstName']?.toString(),
      midName: json['midName']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      groupId: json['groupId']?.toString(),
      subjectGroupName: json['subjectGroupName']?.toString(),
      districtName: json['districtName']?.toString(),
      cityName: json['cityName']?.toString(),
    );
  }
}
